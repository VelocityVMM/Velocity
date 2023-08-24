//
// MIT License
//
// Copyright (c) 2023 zimsneexh
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//

import Foundation
import SQLite

extension VDB {

    /// A permission in the database
    /// > Warning: Altered member variables do not commit to the database unless `commit()` is called on the object
    class Permission : Loggable, Encodable {
        /// The logging context
        internal let context: String
        /// A reference to the database for later use
        internal let db: VDB

        /// The unique permission id
        let pid: Int64
        /// The unique string identifier for this permission
        let name: String
        /// A description of this permission
        let description: String

        /// The encodable keys
        private enum CodingKeys : CodingKey {
            case pid
            case name
            case description
        }

        /// Create a new Permission object
        /// > Warning: This will not create the permission in the database, for this, one should call creating functions
        /// - Parameter db: A reference to the database this group is part of
        /// - Parameter pid: The unique permission id
        /// - Parameter name: The name and string identifier for this permission
        /// - Parameter description: A description for what this permission allows a user to do
        init(db: VDB, pid: Int64, name: String, description: String) {
            self.context = "[vDB::Permission (\(name)[\(pid)])]"
            self.db = db

            self.pid = pid
            self.name = name
            self.description = description
        }

        /// Provides some information about this permission
        func info() -> String {
            return "Permission (pid: \(self.pid), name: '\(self.name)' description: '\(self.description)')"
        }

        /// Provides short information about this permission
        func s_info() -> String {
            return "Permission (pid: \(self.pid), name: '\(self.name)')"
        }

        /// Commits the current state of this permission to the database
        ///
        /// The `pid` remains and is used as the primary key
        func commit() throws {
            let query = self.db.t_permissions.table.insert(or: .replace,
                                                      self.db.t_permissions.pid <- self.pid,
                                                      self.db.t_permissions.name <- self.name,
                                                      self.db.t_permissions.description <- self.description)
            try self.db.db.run(query)
        }

        /// Deletes this permission from the database
        func delete() throws {
            try self.db.db.run(self.db.t_permissions.table.filter(self.db.t_permissions.pid == self.pid).delete())
        }

        /// Creates a new Permission object in the database
        /// - Parameter db: A reference to the `VDB` for later use
        /// - Parameter name: The name and unique identifier for the permission
        /// - Parameter description: A description about the permission
        /// - Parameter pid: (optional) Enforce a specific `pid`
        ///
        /// This function will check for collisions and error out accordingly
        static func create(db: VDB, name: String, description: String, pid: Int64? = nil) throws -> Swift.Result<Permission, Permissions.InsertError> {
            let t  = db.t_permissions

            velocity.VTrace("Inserting permission: \(name) - \(description) - \(String(describing: pid))", "[vDB::Permission]")

            var query = t.table.insert(t.name <- name, t.description <- description)

            // Ensure the name is no duplicate
            if let pid = try db.db.pluck(t.table.select(t.pid).where(t.name == name)) {
                velocity.VTrace("Permission does already exist (name): pid=\(pid[t.pid]) - \(name) - \(description)", "[vDB::Permission]")
                return Swift.Result.failure(.NameExists)
            }

            // If a specific PID is requested, ensure there is no duplicate
            if let pid = pid {
                // Check if the pid does not already exist
                if let pid = try db.db.pluck(t.table.select(t.pid).where(t.name == name)) {
                    velocity.VTrace("Permission does already exist (pid): pid=\(pid[t.pid]) - \(name) - \(description)", "[vDB::Permission]")
                    return .failure(.PIDExists)
                }

                query = t.table.insert(t.name <- name, t.description <- description, t.pid <- pid)
            }

            let pid = try db.db.run(query)

            let permission = Permission(db: db, pid: pid, name: name, description: description)
            permission.VDebug("Inserted \(permission.info())")

            return .success(permission)
        }

        /// Selects a permission from the database by `name`
        /// - Parameter db: A reference to the `VDB` for later use
        /// - Parameter name: The name to search for
        static func select(db: VDB, name: String) throws -> Permission? {
            let t = db.t_permissions

            guard let row = try db.db.pluck(t.table.select(t.name, t.description, t.pid).where(t.name == name)) else {
                return nil
            }

            return Permission(db: db, pid: row[t.pid], name: row[t.name], description: row[t.description])
        }

        /// Selects a permission from the database by `pid`
        /// - Parameter db: A reference to the `VDB` for later use
        /// - Parameter pid: The permission id to search for
        static func select(db: VDB, pid: Int64) throws -> Permission? {
            let t = db.t_permissions

            guard let row = try db.db.pluck(t.table.select(t.name, t.description, t.pid).where(t.pid == pid)) else {
                return nil
            }

            return Permission(db: db, pid: row[t.pid], name: row[t.name], description: row[t.description])
        }

        /// Ensures a permission exists by checking if the `pid` (if supplied) is present or if the name is present. Else this will create a new permission
        /// - Parameter db: A reference to the `VDB` for later use
        /// - Parameter name: The name and string identifier for this permission
        /// - Parameter description: A description for what this permission allows a user to do
        /// - Parameter pid: (optional) Search by `pid` instead of name
        ///
        /// This function will prefer searching by `pid` if supplied. If no permission with the supplied `pid` has been found, it will fall back to searching
        /// by `name`. I no `pid` has been supplied, this will default to search by `name`.
        ///
        /// If no existing permission has been found, this will create the permission from scratch
        static func ensure(db: VDB, name: String, description: String, pid: Int64? = nil) throws -> Permission {
            // If there is a pid, select by pid
            if let pid = pid {
                if let permission = try self.select(db: db, pid: pid) {
                    permission.VTrace("Found permission by pid (\(pid)): \(permission.info())")
                    return permission
                }
            }

            // If no pid is here, or nothing has been found, select by name
            if let permission = try self.select(db: db, name: name) {
                permission.VTrace("Found permission by name (\(name)): \(permission.info())")
                return permission
            }

            // .get() is used here, if there is a duplicate now, something is wrong...
            return try self.create(db: db, name: name, description: description, pid: pid).get()
        }
    }

    /// A template for permission creation
    class PermissionTemplate {
        /// The `name` for the permission
        let name: String
        /// The `description` for the new permission
        let description: String

        init(_ name: String, _ description: String) {
            self.name = name
            self.description = description
        }
    }

    /// The `permissions` table
    class Permissions : Loggable {
        /// The logging context
        let context = "[vDB::Permissions]"
        /// The `permissions` table
        let table = Table("permissions")

        /// The `pid` for the permission
        let pid = Expression<Int64>("pid")
        /// The `name` of the permission
        let name = Expression<String>("name")
        /// The `description` of the permission
        let description = Expression<String>("description")

        /// Ensures the `permissions` table exists
        init(db: Connection) throws {
            VDebug("Ensuring 'permissions' table...")
            // Setup the table
            try db.run(self.table.create(ifNotExists: true) {t in
                t.column(self.pid, primaryKey: .autoincrement)
                t.column(self.name)
                t.column(self.description)

                // The name has to be unique
                t.unique(self.name)
            })
        }

        /// An error that can occur during insertion
        enum InsertError : Error {
            /// The `name` of the permission is not unique
            case NameExists
            case PIDExists
        }
    }

    /// Creates a new `Permission` object in the database
    /// - Parameter name: The name and unique identifier for the permission
    /// - Parameter description: A description about the permission
    /// - Parameter pid: (optional) Enforce a specific `pid`
    ///
    /// This function will check for collisions and error out accordingly
    func permission_create(name: String, description: String, pid: Int64? = nil) throws -> Swift.Result<Permission, Permissions.InsertError> {
        return try Permission.create(db: self, name: name, description: description, pid: pid)
    }

    /// Selects a permission from the database by `name`
    /// - Parameter name: The name to search for
    func permission_select(name: String) throws -> Permission? {
        return try Permission.select(db: self, name: name)
    }

    /// Selects a permission from the database by `pid`
    /// - Parameter pid: The permission id to search for
    func permission_select(pid: Int64) throws -> Permission? {
        return try Permission.select(db: self, pid: pid)
    }

    /// Ensures a permission exists by checking if the `pid` (if supplied) is present or if the name is present. Else this will create a new permission
    /// - Parameter name: The name and string identifier for this permission
    /// - Parameter description: A description for what this permission allows a user to do
    /// - Parameter pid: (optional) Search by `pid` instead of name
    ///
    /// This function will prefer searching by `pid` if supplied. If no permission with the supplied `pid` has been found, it will fall back to searching
    /// by `name`. I no `pid` has been supplied, this will default to search by `name`.
    ///
    /// If no existing permission has been found, this will create the permission from scratch
    func permission_ensure(name: String, description: String, pid: Int64? = nil) throws -> Permission {
        return try Permission.ensure(db: self, name: name, description: description, pid: pid)
    }
}
