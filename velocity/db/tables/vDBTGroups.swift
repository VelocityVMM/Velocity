//
//  vDBTGroups.swift
//  velocity
//
//  Created by Max Kofler on 15/08/23.
//

import Foundation
import SQLite

extension VDB {

    /// A group in the database
    /// > Warning: Altered member variables do not commit to the database unless `commit()` is called on the object
    class Group : Loggable, Encodable {
        /// The logging context
        internal let context: String
        /// A reference to the database for later use
        internal let db: VDB

        /// The unique group id
        let gid: Int64
        /// The `gid` of the parent group
        ///
        /// If this is set to `0`, the parent is the root group. The `root {0}` group has this set to `0`, too
        let parent_gid: Int64
        /// The group name (unique within the parent group)
        var name: String

        /// The encodable keys
        private enum CodingKeys : CodingKey {
            case gid
            case parent_gid
            case name
            case memberships
        }

        /// Provide encoding functionality
        func encode(to encoder: Encoder) throws {
            var container  = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.gid, forKey: .gid)
            try container.encode(self.parent_gid, forKey: .parent_gid)
            try container.encode(self.name, forKey: .name)
            try container.encode(self.get_memberships(), forKey: .memberships)
        }

        /// Create a new Group object.
        /// > Warning: This will not create the group in the database, for this, one should call creating functions
        /// - Parameter db: A reference to the database this group is part of
        /// - Parameter gid: The unique group id for this group
        /// - Parameter parent_gid: The `gid` of the parent group
        init(db: VDB, name: String, gid: Int64, parent_gid: Int64) {
            self.context = "[vDB::Group (\(name){\(gid)})]"
            self.db = db

            self.gid = gid
            self.name = name
            self.parent_gid = parent_gid
        }

        /// Provides an information string describing this group
        func info() -> String {
            return "Group (gid: \(self.gid), parent_gid: \(String(describing: self.parent_gid)), name: '\(self.name)')"
        }

        /// Commits the current state of this group to the database
        ///
        /// The `gid` remains and is used as the primary key
        func commit() throws {
            let query = self.db.t_groups.table.insert(or: .replace,
                                                      self.db.t_groups.gid <- self.gid,
                                                      self.db.t_groups.parent_gid <- self.parent_gid,
                                                      self.db.t_groups.name <- self.name)
            try self.db.db.run(query)
        }

        /// Removes the group from the database
        func delete() throws {
            let query = self.db.t_groups.table.filter(self.db.t_groups.gid == self.gid).delete()
            try self.db.db.run(query)
        }

        struct MembershipInfo : Encodable {
            let uid: Int64
            let name: String
            let permissions: [Permission]
        }

        /// Return all memberships of this group
        func get_memberships() throws -> [MembershipInfo] {
            let t_m = self.db.t_memberships;

            var memberships: [MembershipInfo] = []

            // Iterate over all membership users
            let query = t_m.table.filter(t_m.gid == self.gid).select(distinct: t_m.uid)
            for row_m in try self.db.db.prepare(query) {
                guard let user = try self.db.user_select(uid: row_m[t_m.uid]) else {
                    continue
                }

                var permissions: [Permission] = []

                // Iterate over all permissions on this group
                let query = t_m.table.filter(t_m.gid == self.gid && t_m.uid == user.uid)
                for permission in try self.db.db.prepare(query) {
                    if let permission = try self.db.permission_select(pid: permission[t_m.pid]) {
                        permissions.append(permission)
                    }
                }

                memberships.append(MembershipInfo(uid: user.uid, name: self.name, permissions: permissions))
            }

            return memberships
        }

        /// Returns all the children this group has
        /// - Parameter recursive: If this function should operate recursively
        ///
        /// This function will **always** insert the parent group before the child groups if it operates recursively
        func get_children(recursive: Bool) throws -> [Group] {
            let t_g = self.db.t_groups
            var groups: [Group] = []

            let query = t_g.table.filter(t_g.parent_gid == self.gid && t_g.parent_gid != t_g.gid)

            for row in try db.db.prepare(query) {
                let new_group = Group(db: db, name: row[t_g.name], gid: row[t_g.gid], parent_gid: row[t_g.parent_gid])
                groups.append(new_group)
                if recursive {
                    groups.append(contentsOf: try new_group.get_children(recursive: recursive))
                }
            }

            return groups
        }

        /// Returns the permissions a `uid` has on this group directly, no inherited permissions are listed
        /// - Parameter uid: The `uid` to get the permissions of
        func get_direct_permissions(uid: Int64) throws -> [Permission] {
            let tp = self.db.t_permissions
            let tm = self.db.t_memberships

            let t_res = tm.table.filter(tm.table[tm.uid] == uid && tm.table[tm.gid] == self.gid)
            let query = tp.table.join(t_res, on: tm.table[tm.pid] == tp.table[tp.pid])

            var res: [Permission] = []

            for row in try self.db.db.prepare(query) {
                res.append(Permission(db: self.db, pid: row[tp.table[tp.pid]], name: row[tp.table[tp.name]], description: row[tp.table[tp.description]]))
            }

            return res
        }

        /// Returns the permissions a user has on this group directly, no inherited permissions are listed
        /// - Parameter user: The user to get the permissions of
        func get_direct_permissions(user: User) throws -> [Permission] {
            try self.get_direct_permissions(uid: user.uid)
        }

        /// User-specific group information
        struct UserGroupInfo : Encodable {
            let gid: Int64
            let parent_gid: Int64
            let name: String
            let permissions: [Permission]
        }

        /// Returns information about this group, tailored to the supplied user
        /// - Parameter user: The user to target
        func get_user_group_info(user: User) throws -> UserGroupInfo {
            let info = UserGroupInfo(
                gid: self.gid,
                parent_gid: self.parent_gid,
                name: self.name,
                permissions: try self.get_direct_permissions(uid: user.uid))

            return info
        }

        /// Creates a new group in the database
        /// - Parameter db: The database to use
        /// - Parameter name: The new `name` to use
        /// - Parameter gid: (optional) If set, enforce a `gid` for the new group
        static func create(db: VDB, name: String, parent_gid: Int64, gid: Int64? = nil) throws -> Swift.Result<Group, Groups.InsertError> {
            var n_gid: Int64 = 0

            switch try db.group_insert(name: name, parent_gid: parent_gid, gid: gid) {
            case .success(let gid):
                n_gid = gid
            case .failure(let e):
                return Swift.Result.failure(e)
            }

            return Swift.Result.success(Group(db: db, name: name, gid: n_gid, parent_gid: parent_gid))
        }

        /// Select a group from the database
        /// - Parameter db: The database to use
        /// - Parameter name: The `name` to search for
        /// - Parameter parent_gid: The `gid` of the parent group to search in
        static func select(db: VDB, name: String, parent_gid: Int64) throws -> Group? {
            guard let row = try db.db.pluck(db.t_groups.table.filter(db.t_groups.name == name && db.t_groups.parent_gid == parent_gid)) else {
                return nil
            }

            return Group(db: db, name: row[db.t_groups.name], gid: row[db.t_groups.gid], parent_gid: row[db.t_groups.parent_gid])
        }

        /// Select a group from the database
        /// - Parameter db: The database to use
        /// - Parameter gid: The `gid` to search for
        static func select(db: VDB, gid: Int64) throws -> Group? {
            guard let row = try db.db.pluck(db.t_groups.table.filter(db.t_groups.gid == gid)) else {
                return nil
            }

            return Group(db: db, name: row[db.t_groups.name], gid: row[db.t_groups.gid], parent_gid: row[db.t_groups.parent_gid])
        }

        /// Ensures a group exists in the database. If the `gid` is not `nil`, this will search for an existing group with the provided `gid`, else the `name`.
        /// If no matching group is found, this will create a new group and return it.
        /// - Parameter db: The database to use
        /// - Parameter name: The `name` to search for / use
        /// - Parameter parent_gid: The `gid` of the parent group
        /// - Parameter gid: (optional) The `gid` to search for / use
        static func ensure(db: VDB, name: String, parent_gid: Int64, gid: Int64? = nil) throws -> Swift.Result<Group, Groups.InsertError> {
            // If there is a gid, search for it
            if let gid = gid {
                // If the group has been found, return it
                if let group = try Group.select(db: db, gid: gid) {
                    velocity.VTrace("Found group by gid (\(gid)): \(group.info())", "[vDB::Group]")
                    return Swift.Result.success(group)
                }
            } else {
                // If the group has been found, return it
                if let group = try Group.select(db: db, name: name, parent_gid: parent_gid) {
                    velocity.VTrace("Found group by group name (\(name)): \(group.info())", "[vDB::Group]")
                    return Swift.Result.success(group)
                }
            }

            // Else create a new group
            velocity.VTrace("Creating new group (gid = \(String(describing: gid)), parent_gid = \(parent_gid) name = '\(name)')", "[vDB::Group]")
            return try Self.create(db: db, name: name, parent_gid: parent_gid, gid: gid)
        }

        /// List all available groups
        /// - Parameter db: The database to query and to store for later usage
        static func list(db: VDB) throws -> [Group] {
            var arr: [Group] = []
            let tg = db.t_groups
            let query = tg.table

            for row in try db.db.prepare(query) {
                arr.append(Group(db: db, name: row[tg.name], gid: row[tg.gid], parent_gid: row[tg.parent_gid]))
            }

            return arr
        }
    }

    /// The `groups` table
    class Groups : Loggable {
        /// The logging context
        let context = "[vDB::Groups]"
        /// The `groups` table
        let table = Table("groups")
        /// The unique group id (`gid`)
        let gid = Expression<Int64>("gid")
        /// The `gid` of the parent group
        let parent_gid = Expression<Int64>("parent_gid")
        /// The `name` of the group, unique within the parent group
        let name = Expression<String>("name")

        /// Ensures the `groups` table exists and the `root {0}` group is present
        init(db: Connection) throws {
            VDebug("Ensuring 'groups' table...")
            // Setup the table
            try db.run(self.table.create(ifNotExists: true) {t in
                t.column(self.gid, primaryKey: .autoincrement)
                t.column(self.parent_gid)
                t.column(self.name)

                t.foreignKey(self.parent_gid, references: self.table, self.gid)

                // Create a unique key over parent_gid and name to ensure names are unique within a parent group
                t.unique(self.parent_gid, self.name)
            })

            // Make sure the root {0} group exists
            if try !db.exists(self.table, self.gid == 0 && self.parent_gid == 0) {
                let _ = try self.insert(db, name: "root", parent_gid: 0, gid: 0).get()
            }
        }

        /// An error that can occur during insertion
        enum InsertError : Error {
            /// The `gid` is not unique to the table
            case GIDExists
            /// The name is not unique to the parent group
            case GroupNameExists
        }

        /// Inserts a new group into the table
        /// - Parameter db: The database connection to insert into
        /// - Parameter name: The name of the new group to create
        /// - Parameter parent_gid: The `gid` of the parent group
        /// - Parameter gid: (optional) The desired `gid`
        func insert(_ db: Connection, name: String, parent_gid: Int64, gid: Int64? = nil) throws -> Swift.Result<Int64, InsertError> {
            VTrace("Inserting group (gid = \(String(describing: gid)), parent_gid = \(parent_gid) name = '\(name)')")

            // Check if the name is unique within the parent group
            if (try db.exists(self.table, self.name == name && self.parent_gid == parent_gid)) {
                VTrace("Group with name '\(name)' does already exist within group {\(parent_gid)}")
                return Swift.Result.failure(.GroupNameExists)
            }

            var query = self.table.insert(self.name <- name, self.parent_gid <- parent_gid)

            // If a specific GID is requested
            if let gid = gid {
                // Check if the gid is unique
                if (try db.exists(self.table, self.gid == gid)) {
                    VTrace("Group with gid '\(gid)' does already exist")
                    return Swift.Result.failure(.GIDExists)
                }

                query = self.table.insert(self.name <- name, self.gid <- gid, self.parent_gid <- parent_gid)
            }

            try db.run(query)
            let new_gid = try db.pluck(self.table.where(self.name == name))!.get(self.gid)

            VDebug("Inserted group (gid = \(new_gid), parent_gid = \(parent_gid) name = '\(name)')")

            return Swift.Result.success(new_gid)
        }
    }

    /// Inserts a new group into the `groups` table
    /// - Parameter name: The name of the new group to create
    /// - Parameter parent_gid: The `gid` of the parent group
    /// - Parameter gid: (optional) The desired `gid`
    func group_insert(name: String, parent_gid: Int64, gid: Int64? = nil) throws -> Swift.Result<Int64, Groups.InsertError> {
        return try self.t_groups.insert(self.db, name: name, parent_gid: parent_gid, gid: gid)
    }

    /// Creates a new group in the database
    /// - Parameter name: The new `name` to use
    /// - Parameter parent_gid: The `gid` of the parent group
    /// - Parameter gid: (optional) If set, enforce a `gid` for the new group
    func group_create(name: String, parent_gid: Int64, gid: Int64? = nil) throws -> Swift.Result<Group, Groups.InsertError> {
        return try Group.create(db: self, name: name, parent_gid: parent_gid, gid: gid)
    }

    /// Select a group from the database
    /// - Parameter name: The `name` to search for
    /// - Parameter parent_gid: The `gid` of the parent group
    func group_select(name: String, parent_gid: Int64) throws -> Group? {
        return try Group.select(db: self, name: name, parent_gid: parent_gid)
    }

    /// Select a group from the database
    /// - Parameter gid: The `gid` to search for
    func group_select(gid: Int64) throws -> Group? {
        return try Group.select(db: self, gid: gid)
    }

    /// Ensures a group exists in the database. If the `gid` is not `nil`, this will search for an existing group with the provided `gid`, else the `groupname`.
    /// If no matching group is found, this will create a new group and return it.
    /// - Parameter name: The `groupname` to search for / use
    /// - Parameter parent_gid: The `gid` of the parent group
    /// - Parameter gid: (optional) The `gid` to search for / use
    func group_ensure(name: String, parent_gid: Int64, gid: Int64? = nil) throws -> Swift.Result<Group, Groups.InsertError> {
        return try Group.ensure(db: self, name: name, parent_gid: parent_gid, gid: gid)
    }

    /// List back all groups available in this database
    func group_list() throws -> [Group] {
        return try Group.list(db: self)
    }
}
