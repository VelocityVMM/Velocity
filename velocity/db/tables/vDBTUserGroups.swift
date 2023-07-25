//
//  vDBTUserGroups.swift
//  velocity
//
//  Created by Max Kofler on 25/07/23.
//

import Foundation
import SQLite

extension VDB {

    /// The `usergroups` table
    struct UserGroups : Loggable {
        let context = "[vDB::UserGroups]";
        let table = Table("usergroups");
        let uid = Expression<Int64>("uid");
        let gid = Expression<Int64>("gid");

        init(db: Connection, users: Users, groups: Groups) throws {
            VDebug("Ensuring 'usergroups' table...");
            // Setup the table
            try db.run(self.table.create(ifNotExists: true){t in
                t.column(self.uid);
                t.column(self.gid);

                t.foreignKey(self.uid, references: users.table, users.uid, update: .cascade, delete: .cascade);
                t.foreignKey(self.gid, references: groups.table, groups.gid, update: .cascade, delete: .cascade);

                t.primaryKey(self.uid, self.gid);
            });
        }
    }
}
