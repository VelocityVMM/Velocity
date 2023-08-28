//
//  vDBUsers.swift
//  velocity
//
//  Created by Max Kofler on 23/07/23.
//

import Foundation
import SQLite

extension VDB {

    /// A user in the database
    /// > Warning: Altered member variables do not commit to the database unless `commit()` is called on the object
    class User : Loggable, Encodable {
        /// The logging context
        internal let context: String;
        /// A reference to the database for later use
        internal let db: VDB;

        /// The unique user id
        let uid: Int64;
        /// The unique username
        var username: String;
        /// The password in hashed form
        var pwhash: String;

        /// The encodable keys
        private enum CodingKeys : CodingKey {
            case uid
            case name
            case memberships
        }

        /// Provide encoding functionality
        func encode(to encoder: Encoder) throws {
            var container  = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.uid, forKey: .uid)
            try container.encode(self.username, forKey: .name)
            try container.encode(self.get_memberships(), forKey: .memberships)
        }

        /// Create a new User object.
        /// > Warning: This will not create the user in the database, for this, one should call creating functions
        init (db: VDB, username: String, pwhash: String, uid: Int64) {
            self.context = "[vDB::User (\(username){\(uid)})]";
            self.db = db;
            self.username = username;
            self.pwhash = pwhash;
            self.uid = uid;
        }

        /// Provides an information string describing this user
        func info() -> String {
            return "User (uid: \(self.uid), username: '\(self.username)')";
        }

        /// Commits the current state of this user to the database
        ///
        /// The `uid` remains and is used as the primary key
        func commit() throws {
            let query = self.db.t_users.table.insert(or: .replace,
                                                     self.db.t_users.uid <- self.uid,
                                                     self.db.t_users.username <- self.username,
                                                     self.db.t_users.password <- self.pwhash);
            try self.db.db.run(query);
        }

        /// Removes the user from the database
        func delete() throws {
            let query = self.db.t_users.table.filter(self.db.t_users.uid == self.uid).delete();
            try self.db.db.run(query);
        }

        /// Returns all the permissions a user has on a group
        /// - Parameter group: The group to check for permissions
        func get_permissions(group: Group) throws -> [Permission] {
            let tm = self.db.t_memberships
            let tg = self.db.t_groups

            let stmt_s =
            """
            WITH RECURSIVE tree(\(tg.gid), \(tg.parent_gid)) AS (
                SELECT \(tg.gid), \(tg.parent_gid) FROM groups WHERE \(tg.gid) = \(group.gid)
                UNION ALL
                SELECT t.\(tg.gid), t.\(tg.parent_gid) FROM groups t
                JOIN tree ON tree.parent_gid = t.\(tg.gid)
                WHERE t.\(tg.parent_gid) != t.\(tg.gid)
            )

            SELECT DISTINCT \(tm.pid) FROM memberships WHERE
                (\(tg.gid) IN (SELECT \(tg.gid) FROM tree)
                OR \(tg.gid) = 0)
                AND \(tm.uid) = \(self.uid);
            """

            var permissions: [Permission] = []

            for r in try self.db.db.prepare(stmt_s) {
                guard let pid = r[0] as? Int64 else {
                    continue
                }

                if let permission = try self.db.permission_select(pid: pid) {
                    permissions.append(permission)
                }
            }

            return permissions
        }

        /// Returns if this user has the permission on the group
        /// - Parameter permission: The permission to search for
        /// - Parameter group: The group the user has the permission on (`nil` for anything)
        ///
        /// If the `group` parameter is `nil`, this will check if the user has the permission anywhere
        func has_permission(permission: Permission, group: Group?) throws -> Bool {
            let tm = self.db.t_memberships
            let tg = self.db.t_groups

            guard let group = group else {
                return try self.db.db.exists(tm.table, tm.pid == permission.pid && tm.uid == self.uid)
            }

            let stmt_s =
            """
            WITH RECURSIVE tree(\(tg.gid), \(tg.parent_gid)) AS (
                SELECT \(tg.gid), \(tg.parent_gid) FROM groups WHERE \(tg.gid) = \(group.gid)
                UNION ALL
                SELECT t.\(tg.gid), t.\(tg.parent_gid) FROM groups t
                JOIN tree ON tree.parent_gid = t.\(tg.gid)
                WHERE t.\(tg.parent_gid) != t.\(tg.gid)
            )

            SELECT COUNT(*) FROM memberships WHERE
                (\(tg.gid) IN (SELECT \(tg.gid) FROM tree)
                OR \(tg.gid) = 0)
                AND \(tm.uid) = \(self.uid)
                AND \(tm.pid) = \(permission.pid);
            """

            guard let count_permissions = try! self.db.db.scalar(stmt_s) else {
                return false
            }

            guard let count_permissions = count_permissions as? Int64 else {
                return false
            }

            return count_permissions > 0
        }

        /// Returns if this user has the permissino on the group
        /// - Parameter permission: The permission string to search for
        /// - Parameter group: The group the user has the permission on (`nil` for anything)
        ///
        /// If the `group` parameter is `nil`, this will check if the user has the permission anywhere
        func has_permission(permission: String, group: Group?) throws -> Bool {
            guard let permission = try self.db.permission_select(name: permission) else {
                VTrace("Permission '\(permission)' does not exist")
                return false
            }

            return try self.has_permission(permission: permission, group: group)
        }

        /// Adds a permission of this user on a group
        /// - Parameter group: The group the user should have the permission on
        /// - Parameter permission: The permission to assign
        func add_permission(group: Group, permission: Permission) throws {
            VTrace("Adding permission '\(permission.s_info())' on \(group.info())")

            /// Check if the permission doesn't exist already
            if try self.has_permission(permission: permission, group: group) {
                VTrace("\(permission.s_info()) does exist on \(group.info())")
                return
            }

            let tm = self.db.t_memberships

            let query = tm.table.insert(tm.gid <- group.gid, tm.uid <- self.uid, tm.pid <- permission.pid)

            try self.db.db.run(query)

            VDebug("Added \(permission.s_info()) on \(group.info())")
        }

        /// Adds a permission of this user on a group
        /// - Parameter group: The group the user should have the permission on
        /// - Parameter permission: The permission string to assign
        /// - Returns: `false` if the permission hasn't been found
        func add_permission(group: Group, permission: String) throws -> Bool {
            /// Get the permission
            guard let permission = try self.db.permission_select(name: permission) else {
                VTrace("Permission '\(permission)' does not exist")
                return false
            }

            try self.add_permission(group: group, permission: permission)
            return true
        }

        /// Information about a membership
        struct MembershipInfo : Encodable {
            let gid: Int64
            let parent_gid: Int64
            let name: String
            let permissions: [Permission]
        }

        /// Returns all the memberships that apply to this user and give it permissions
        func get_memberships() throws -> [MembershipInfo] {
            let t_m = self.db.t_memberships;

            var memberships: [MembershipInfo] = []

            // Iterate over all membership groups
            let query = t_m.table.filter(t_m.uid == self.uid).select(distinct: t_m.gid)
            for row_m in try self.db.db.prepare(query) {
                guard let group = try self.db.group_select(gid: row_m[t_m.gid]) else {
                    continue
                }

                var permissions: [Permission] = []

                // Iterate over all permissions on this group
                let query = t_m.table.filter(t_m.uid == self.uid && t_m.gid == group.gid)
                for permission in try self.db.db.prepare(query) {
                    if let permission = try self.db.permission_select(pid: permission[t_m.pid]) {
                        permissions.append(permission)
                    }
                }

                memberships.append(MembershipInfo(gid: group.gid, parent_gid: group.parent_gid, name: group.name, permissions: permissions))
            }

            return memberships
        }

        /// Creates a new user in the database
        /// - Parameter db: The database to use
        /// - Parameter username: The new username to use
        /// - Parameter password: The new password to use
        /// - Parameter uid: (optional) If set, enforce a `uid` for the new user
        static func create(db: VDB, username: String, password: String, uid: Int64? = nil) throws -> Swift.Result<User, Users.InsertError> {
            let pwhash = VDB.hash_pw(password);
            var n_uid: Int64 = 0;

            switch try db.user_insert(username: username, pwhash: pwhash, uid: uid) {
            case .success(let uid):
                n_uid = uid;
            case .failure(let e):
                return Swift.Result.failure(e);
            }

            return Swift.Result.success(User(db: db, username: username, pwhash: pwhash, uid: n_uid));
        }

        /// Select a user from the database
        /// - Parameter db: The database to use
        /// - Parameter username: The `username` to search for
        static func select(db: VDB, username: String) throws -> User? {
            guard let row = try db.db.pluck(db.t_users.table.filter(db.t_users.username == username)) else {
                return nil;
            }

            return User(db: db, username: row[db.t_users.username], pwhash: row[db.t_users.password], uid: row[db.t_users.uid]);
        }

        /// Select a user from the database
        /// - Parameter db: The database to use
        /// - Parameter uid: The `uid` to search for
        static func select(db: VDB, uid: Int64) throws -> User? {
            guard let row = try db.db.pluck(db.t_users.table.filter(db.t_users.uid == uid)) else {
                return nil;
            }

            return User(db: db, username: row[db.t_users.username], pwhash: row[db.t_users.password], uid: row[db.t_users.uid]);
        }

        /// Ensures a user exists in the database. If the `uid` is not `nil`, this will search for an existing user with the provided `uid`, else the `username`.
        /// If no matching user is found, this will create a new user and return it.
        /// - Parameter db: The database to use
        /// - Parameter username: The `username` to search for / use
        /// - Parameter password: The `password` to use
        /// - Parameter uid: (optional) The `uid` to search for / use
        static func ensure(db: VDB, username: String, password: String, uid: Int64? = nil) throws -> Swift.Result<User, Users.InsertError> {
            // If there is a uid, search for it
            if let uid = uid {
                // If the user has been found, return it
                if let user = try User.select(db: db, uid: uid) {
                    velocity.VTrace("Found user by uid (\(uid)): \(user.info())", "[vDB::User]");
                    return Swift.Result.success(user);
                }
            } else {
                // If the user has been found, return it
                if let user = try User.select(db: db, username: username) {
                    velocity.VTrace("Found user by username (\(username)): \(user.info())", "[vDB::User]");
                    return Swift.Result.success(user);
                }
            }

            // Else create a new user
            velocity.VTrace("Creating new user (uid = \(String(describing: uid)), name = '\(username)')", "[vDB::User]");
            return try Self.create(db: db, username: username, password: password, uid: uid);
        }

        /// Checks if a user exists in the database
        /// - Parameter db: The database to consult
        /// - Parameter username: The `username` to search for
        static func exists(db: VDB, username: String) throws -> Bool {
            return try db.db.exists(db.t_users.table, db.t_users.username == username)
        }

        /// Checks if a user exists in the database
        /// - Parameter db: The database to consult
        /// - Parameter uid: The `uid` to search for
        static func exists(db: VDB, uid: Int64) throws -> Bool {
            return try db.db.exists(db.t_users.table, db.t_users.uid == uid)
        }

        /// List all available users
        /// - Parameter db: The database to query and to store for later usage
        static func list(db: VDB) throws -> [User] {
            var arr: [User] = []
            let tu = db.t_users
            let query = tu.table

            for row in try db.db.prepare(query) {
                arr.append(User(db: db, username: row[tu.username], pwhash: row[tu.password], uid: row[tu.uid]))
            }

            return arr
        }
    }

    /// The `users` table
    class Users : Loggable{
        let context = "[vDB::Users]";
        let table = Table("users");
        let uid = Expression<Int64>("uid");
        let username = Expression<String>("username");
        let password = Expression<String>("password");

        init (db: Connection) throws {
            VDebug("Ensuring 'users' table...");
            try db.run(self.table.create(ifNotExists: true) {t in
                t.column(self.uid, primaryKey: .autoincrement);
                t.column(self.username, unique: true);
                t.column(self.password);
            });
            try db.run(self.table.createIndex(self.username, ifNotExists: true));
        }

        /// An error that can occur during insertion
        enum InsertError : Error {
            /// The UID is not unique to the table
            case UIDExists
            /// The username is not unique to the table
            case UsernameExists
        }

        /// Inserts a new user into the table
        /// - Parameter db: The database connection to insert into
        /// - Parameter username: The username to use
        /// - Parameter pwhash: The password for the user in hashed form
        /// - Parameter uid: (optional) Desired UID
        func insert(_ db: Connection, username: String, pwhash: String, uid: Int64? = nil) throws -> Swift.Result<Int64, InsertError> {
            VTrace("Inserting user (uid = \(String(describing: uid)), name = '\(username)')");

            // Check if the username is unique
            if (try db.exists(self.table, self.username == username)) {
                VTrace("User with username '\(username)' does already exist");
                return Swift.Result.failure(.UsernameExists);
            }

            var query = self.table.insert(self.username <- username, self.password <- pwhash);

            // If a specific UID is requested
            if let uid = uid {
                // Check if the uid is unique
                if (try db.exists(self.table, self.uid == uid)) {
                    VTrace("User with uid '\(uid)' does already exist");
                    return Swift.Result.failure(.UIDExists);
                }

                query = self.table.insert(self.uid <- uid, self.username <- username, self.password <- pwhash);
            }

            try db.run(query);
            let new_uid = try db.pluck(self.table.where(self.username == username))!.get(self.uid);

            VDebug("Inserted user '\(username)', uid = \(new_uid)");

            return Swift.Result.success(new_uid);
        }
    }

    /// Inserts a new user into the `users` table
    /// - Parameter username: The username to use
    /// - Parameter pwhash: The password for the user in hashed form
    /// - Parameter uid: (optional) Desired UID
    func user_insert(username: String, pwhash: String, uid: Int64? = nil) throws -> Swift.Result<Int64, Users.InsertError> {
        return try self.t_users.insert(self.db, username: username, pwhash: pwhash, uid: uid);
    }

    /// Creates a new user in the database
    /// - Parameter username: The new username to use
    /// - Parameter password: The new password to use
    /// - Parameter uid: (optional) If set, enforce a `uid` for the new user
    func user_create(username: String, password: String, uid: Int64? = nil) throws -> Swift.Result<User, Users.InsertError> {
        return try User.create(db: self, username: username, password: password, uid: uid);
    }

    /// Select a user from the database
    /// - Parameter username: The `username` to search for
    func user_select(username: String) throws -> User? {
        return try User.select(db: self, username: username);
    }

    /// Select a user from the database
    /// - Parameter uid: The `uid` to search for
    func user_select(uid: Int64) throws -> User? {
        return try User.select(db: self, uid: uid);
    }

    /// Ensures a user exists in the database. If the `uid` is not `nil`, this will search for an existing user with the provided `uid`, else the `username`.
    /// If no matching user is found, this will create a new user and return it.
    /// - Parameter username: The username to search for / use
    /// - Parameter password: The password to use
    /// - Parameter uid: (optional) The uid to search for / use
    func user_ensure(username: String, password: String, uid: Int64? = nil) throws -> Swift.Result<User, Users.InsertError> {
        return try User.ensure(db: self, username: username, password: password, uid: uid);
    }

    /// Checks if a user exists in the database
    /// - Parameter username: The `username` to search for
    func user_exists(username: String) throws -> Bool {
        return try User.exists(db: self, username: username)
    }

    /// Checks if a user exists in the database
    /// - Parameter uid: The `uid` to search for
    func user_exists(uid: Int64) throws -> Bool {
        return try User.exists(db: self, uid: uid)
    }

    /// List back all users available in this database
    func user_list() throws -> [User] {
        return try User.list(db: self)
    }

    /// Hashes a password using a hashing algorithm
    /// - Parameter pw: The password string to hash
    static func hash_pw(_ pw: String) -> String {
        return pw.sha256();
    }
}
