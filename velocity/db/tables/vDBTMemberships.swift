//
// MIT License
//
// Copyright (c) 2023 The Velocity contributors
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

    /// The `memberships` table
    class Memberships : Loggable {
        /// The logging context
        let context = "[vDB::Memberships]"
        /// The `permissions` table
        let table = Table("memberships")

        let gid = Expression<Int64>("gid")
        let uid = Expression<Int64>("uid")
        let pid = Expression<Int64>("pid")

        /// Ensures the `permissions` table exists
        init(db: Connection, groups: Groups, users: Users, permissions: Permissions) throws {
            VDebug("Ensuring 'memberships' table...")
            // Setup the table
            try db.run(self.table.create(ifNotExists: true) {t in
                t.column(self.gid)
                t.column(self.uid)
                t.column(self.pid)

                t.primaryKey(self.gid, self.uid, self.pid)

                t.foreignKey(self.gid, references: groups.table, groups.gid)
                t.foreignKey(self.uid, references: users.table, users.uid)
                t.foreignKey(self.pid, references: permissions.table, permissions.pid)
            })
        }
    }
}
