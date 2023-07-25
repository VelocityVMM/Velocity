//
//  vDBUsers.swift
//  velocity
//
//  Created by Max Kofler on 23/07/23.
//

import Foundation
import SQLite

extension VDB {

    /// The `users` table
    struct Users : Loggable{
        let context = "[vDB::Users]";
        let table = Table("users");
        let uid = Expression<Int64>("uid");
        let username = Expression<String>("username");
        let password = Expression<String>("password");

        init (db: Connection) throws {
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

            var query = self.table.insert(self.username <- username, self.password <- password);

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
}
