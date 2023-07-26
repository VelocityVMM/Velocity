//
//  vDBGroups.swift
//  velocity
//
//  Created by Max Kofler on 24/07/23.
//

import Foundation
import SQLite

extension VDB {

    /// A group in the database
    /// > Warning: Altered member variables do not commit to the database unless `commit()` is called on the object
    class Group : Loggable {
        /// The logging context
        internal let context: String;
        /// A reference to the database for later use
        internal let db: VDB;

        /// The unique group id
        let gid: Int64;
        /// The unique group name
        var groupname: String;

        /// Create a new Group object.
        /// > Warning: This will not create the group in the database, for this, one should call creating functions
        init(db: VDB, groupname: String, gid: Int64) {
            self.context = "[vDB::Group (\(groupname){\(gid)})]";
            self.db = db;

            self.gid = gid;
            self.groupname = groupname;
        }

        /// Provides an information string describing this group
        func info() -> String {
            return "Group (gid: \(self.gid), groupname: '\(self.groupname)')";
        }

        /// Commits the current state of this group to the database
        ///
        /// The `gid` remains and is used as the primary key
        func commit() throws {
            let query = self.db.t_groups.table.insert(or: .replace,
                                                      self.db.t_groups.gid <- self.gid,
                                                      self.db.t_groups.name <- self.groupname);
            try self.db.db.run(query);
        }

        /// Removes the group from the database
        func delete() throws {
            let query = self.db.t_groups.table.filter(self.db.t_groups.gid == self.gid).delete();
            try self.db.db.run(query);
        }

        /// Assigns a user to this group
        /// - Parameter user: The user to assign
        /// - Returns: `false` is the user does not exist in the database, else `true`
        @discardableResult
        func assign_user(user: User) throws -> Bool {
            VDebug("Assigning \(user.info())");
            return try self.assign_user(uid: user.uid);
        }

        /// Assigns a user id to this group
        /// - Parameter uid: The user id to assign to this group
        /// - Returns: `false` is the user does not exist in the database, else `true`
        @discardableResult
        func assign_user(uid: Int64) throws -> Bool {
            VDebug("Assigning user with id {\(uid)}");

            // Check if the user exists
            if (try !self.db.db.exists(self.db.t_users.table, self.db.t_users.uid == uid)) {
                VDebug("User id {\(uid)} does not exist");
                return false;
            }

            let query = self.db.t_usergroups.table.insert(or: .replace,
                                                          self.db.t_usergroups.uid <- uid,
                                                          self.db.t_usergroups.gid <- self.gid);

            try self.db.db.run(query);
            return true;
        }

        /// Removes a user from this group
        /// - Parameter user: The user to remove
        /// - Returns: `false` is the user does not exist in the database, else `true`
        @discardableResult
        func remove_user(user: User) throws -> Bool{
            VDebug("Removing \(user.info())");
            return try self.remove_user(uid: user.uid);
        }

        /// Removes a user id from this group
        /// - Parameter uid: The user id to remove from this group
        /// - Returns: `false` is the user does not exist in the database, else `true`
        @discardableResult
        func remove_user(uid: Int64) throws -> Bool {
            VDebug("Removing user with id {\(uid)}");

            // Check if the user exists
            if (try !self.db.db.exists(self.db.t_users.table, self.db.t_users.uid == uid)) {
                VDebug("User id {\(uid)} does not exist");
                return false;
            }

            let query = self.db.t_usergroups.table.filter(self.db.t_usergroups.uid == uid &&
                                                          self.db.t_usergroups.gid == self.gid).delete();

            try self.db.db.run(query);
            return true;
        }

        /// Creates a new group in the database
        /// - Parameter db: The database to use
        /// - Parameter groupname: The new `groupname` to use
        /// - Parameter gid: (optional) If set, enforce a `gid` for the new group
        static func create(db: VDB, groupname: String, gid: Int64? = nil) throws -> Swift.Result<Group, Groups.InsertError> {
            var n_gid: Int64 = 0;

            switch try db.group_insert(name: groupname, gid: gid) {
            case .success(let gid):
                n_gid = gid;
            case .failure(let e):
                return Swift.Result.failure(e);
            }

            return Swift.Result.success(Group(db: db, groupname: groupname, gid: n_gid));
        }

        /// Select a group from the database
        /// - Parameter db: The database to use
        /// - Parameter groupname: The `groupname` to search for
        static func select(db: VDB, groupname: String) throws -> Group? {
            guard let row = try db.db.pluck(db.t_groups.table.filter(db.t_groups.name == groupname)) else {
                return nil;
            }

            return Group(db: db, groupname: row[db.t_groups.name], gid: row[db.t_groups.gid]);
        }

        /// Select a group from the database
        /// - Parameter db: The database to use
        /// - Parameter gid: The `gid` to search for
        static func select(db: VDB, gid: Int64) throws -> Group? {
            guard let row = try db.db.pluck(db.t_groups.table.filter(db.t_groups.gid == gid)) else {
                return nil;
            }

            return Group(db: db, groupname: row[db.t_groups.name], gid: row[db.t_groups.gid]);
        }

        /// Ensures a group exists in the database. If the `gid` is not `nil`, this will search for an existing group with the provided `gid`, else the `groupname`.
        /// If no matching group is found, this will create a new group and return it.
        /// - Parameter db: The database to use
        /// - Parameter groupname: The `groupname` to search for / use
        /// - Parameter gid: (optional) The `gid` to search for / use
        static func ensure(db: VDB, groupname: String, gid: Int64? = nil) throws -> Swift.Result<Group, Groups.InsertError> {
            // If there is a gid, search for it
            if let gid = gid {
                // If the group has been found, return it
                if let group = try Group.select(db: db, gid: gid) {
                    velocity.VTrace("Found group by gid (\(gid)): \(group.info())", "[vDB::Group]");
                    return Swift.Result.success(group);
                }
            } else {
                // If the group has been found, return it
                if let group = try Group.select(db: db, groupname: groupname) {
                    velocity.VTrace("Found group by groupname (\(groupname)): \(group.info())", "[vDB::Group]");
                    return Swift.Result.success(group);
                }
            }

            // Else create a new group
            velocity.VTrace("Creating new group (gid = \(String(describing: gid)), name = '\(groupname)')", "[vDB::Group]");
            return try Self.create(db: db, groupname: groupname, gid: gid);
        }
    }

    /// The `groups` table
    struct Groups : Loggable {
        let context = "[vDB::Groups]";
        let table = Table("groups");
        let gid = Expression<Int64>("gid");
        let name = Expression<String>("name");

        init(db: Connection) throws {
            VDebug("Ensuring 'groups' table...");
            // Setup the table
            try db.run(self.table.create(ifNotExists: true) {t in
                t.column(self.gid, primaryKey: .autoincrement);
                t.column(self.name, unique: true);
            });
            try db.run(self.table.createIndex(self.name, ifNotExists: true));
        }

        /// An error that can occur during insertion
        enum InsertError : Error {
            /// The GID is not unique to the table
            case GIDExists
            /// The name is not unique to the table
            case GroupNameExists
        }

        /// Inserts a new group into the table
        /// - Parameter db: The database connection to insert into
        /// - Parameter name: The name of the new group to create
        /// - Parameter gid: (optional) The desired GID
        func insert(_ db: Connection, name: String, gid: Int64? = nil) throws -> Swift.Result<Int64, InsertError> {
            VTrace("Inserting group (gid = \(String(describing: gid)), name = '\(name)')");

            // Check if the username is unique
            if (try db.exists(self.table, self.name == name)) {
                VTrace("Group with name '\(name)' does already exist");
                return Swift.Result.failure(.GroupNameExists);
            }

            var query = self.table.insert(self.name <- name);

            // If a specific UID is requested
            if let gid = gid {
                // Check if the uid is unique
                if (try db.exists(self.table, self.gid == gid)) {
                    VTrace("Group with gid '\(gid)' does already exist");
                    return Swift.Result.failure(.GIDExists);
                }

                query = self.table.insert(self.name <- name, self.gid <- gid);
            }

            try db.run(query);
            let new_gid = try db.pluck(self.table.where(self.name == name))!.get(self.gid);

            VDebug("Inserted group (gid = \(new_gid), name = '\(name)')");

            return Swift.Result.success(new_gid);
        }
    }

    /// Inserts a new group into the `groups` table
    /// - Parameter name: The name of the new group to create
    /// - Parameter gid: (optional) The desired GID
    func group_insert(name: String, gid: Int64? = nil) throws -> Swift.Result<Int64, Groups.InsertError> {
        return try self.t_groups.insert(self.db, name: name, gid: gid);
    }

    /// Creates a new group in the database
    /// - Parameter groupname: The new `groupname` to use
    /// - Parameter gid: (optional) If set, enforce a `gid` for the new group
    func group_create(groupname: String, gid: Int64? = nil) throws -> Swift.Result<Group, Groups.InsertError> {
        return try Group.create(db: self, groupname: groupname, gid: gid);
    }

    /// Select a group from the database
    /// - Parameter groupname: The `groupname` to search for
    func group_select(groupname: String) throws -> Group? {
        return try Group.select(db: self, groupname: groupname);
    }

    /// Select a group from the database
    /// - Parameter gid: The `gid` to search for
    func group_select(gid: Int64) throws -> Group? {
        return try Group.select(db: self, gid: gid);
    }

    /// Ensures a group exists in the database. If the `gid` is not `nil`, this will search for an existing group with the provided `gid`, else the `groupname`.
    /// If no matching group is found, this will create a new group and return it.
    /// - Parameter groupname: The `groupname` to search for / use
    /// - Parameter gid: (optional) The `gid` to search for / use
    func group_ensure(groupname: String, gid: Int64? = nil) throws -> Swift.Result<Group, Groups.InsertError> {
        return try Group.ensure(db: self, groupname: groupname, gid: gid);
    }
}
