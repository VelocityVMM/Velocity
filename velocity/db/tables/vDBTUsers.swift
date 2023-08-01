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
    class User : Loggable {
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

        /// Returns an array of the groups this user is a member of
        func get_groups() throws -> [Group] {
            let query = self.db.t_groups.table
                .select(distinct: self.db.t_groups.table[self.db.t_groups.gid], self.db.t_groups.name)
                .join(self.db.t_usergroups.table, on: self.db.t_usergroups.table[self.db.t_usergroups.gid] == self.db.t_groups.table[self.db.t_groups.gid])

            var groups: [Group] = []
            for group in try self.db.db.prepare(query) {
                let group = Group(db: self.db, groupname: group[self.db.t_groups.name], gid: group[self.db.t_groups.gid])
                groups.append(group)
            }

            return groups
        }

        /// Checks if the user is a member of the supplied group
        /// - Parameter group: The group to check for
        func is_member_of(group: Group) throws -> Bool {
            return try self.is_member_of(gid: group.gid)
        }

        /// Checks if the user is a member of the supplied group
        /// - Parameter gid: The group id of the group to check for
        func is_member_of(gid: Int64) throws -> Bool {
            return try self.db.db.exists(self.db.t_usergroups.table, self.db.t_usergroups.uid == self.uid && self.db.t_usergroups.gid == gid)
        }

        /// Checks if the user is a member of the supplied group
        /// - Parameter groupname: The name of the group to check for
        func is_member_of(groupname: String) throws -> Bool {
            guard let grp = try self.db.group_select(groupname: groupname) else {
                return false
            }

            return try self.db.db.exists(self.db.t_usergroups.table, self.db.t_usergroups.uid == self.uid && self.db.t_usergroups.gid == grp.gid)
        }

        /// Joins a group
        /// - Parameter group: The group to join
        /// - Returns: `false` is the group does not exist in the database, else `true`
        @discardableResult
        func join_group(group: Group) throws -> Bool {
            VDebug("Joining \(group.info())");
            return try self.join_group(gid: group.gid);
        }

        /// Joins a group with the supplied gid
        /// - Parameter gid: The group to join
        /// - Returns: `false` is the group does not exist in the database, else `true`
        @discardableResult
        func join_group(gid: Int64) throws -> Bool {
            VDebug("Joining group {\(gid)}");

            // Check if the group exists
            if (try !self.db.db.exists(self.db.t_groups.table, self.db.t_groups.gid == gid)) {
                VDebug("Group id {\(gid)} does not exist");
                return false;
            }

            let query = self.db.t_usergroups.table.insert(or: .replace,
                                                          self.db.t_usergroups.uid <- self.uid,
                                                          self.db.t_usergroups.gid <- gid);

            try self.db.db.run(query);
            return true;
        }

        /// Leaves a group
        /// - Parameter group: The group to leave
        /// - Returns: `false` is the group does not exist in the database, else `true`
        @discardableResult
        func leave_group(group: Group) throws -> Bool {
            VDebug("Leaving \(group.info())");
            return try self.leave_group(gid: group.gid);
        }

        /// Leaves a group with the supplied gid
        /// - Parameter gid: The group to leave
        /// - Returns: `false` is the group does not exist in the database, else `true`
        @discardableResult
        func leave_group(gid: Int64) throws -> Bool {
            VDebug("Leaving group {\(gid)}");

            // Check if the group exists
            if (try !self.db.db.exists(self.db.t_groups.table, self.db.t_groups.gid == gid)) {
                VDebug("Group id {\(gid)} does not exist");
                return false;
            }

            let query = self.db.t_usergroups.table.filter(self.db.t_usergroups.uid == self.uid &&
                                                          self.db.t_usergroups.gid == gid).delete();

            try self.db.db.run(query);
            return true;
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
    }

    /// The `users` table
    struct Users : Loggable{
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

    /// Hashes a password using a hashing algorithm
    /// - Parameter pw: The password string to hash
    static func hash_pw(_ pw: String) -> String {
        return pw.sha256();
    }
}
