//
//  vDBGroups.swift
//  velocity
//
//  Created by Max Kofler on 24/07/23.
//

import Foundation
import SQLite

extension VDB {

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
}
