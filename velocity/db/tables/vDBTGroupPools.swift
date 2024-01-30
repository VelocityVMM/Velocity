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
    /// The `grouppools` table, connecting groups to mediapools
    class TGroupPools : Loggable {
        /// The logging context
        internal let context: String = "[vDB::TGroupPools]"

        /// The `grouppools` table
        let table = Table("grouppools")

        /// The `mpid` of the media pool to connect
        let mpid = Expression<MPID>("pid")
        /// The `gid` of the group to connect
        let gid = Expression<GID>("gid")
        /// The quota in bytes the group has available
        let quota = Expression<Int64>("quota")
        /// If the group is allowed to write to media in the target pool
        let write = Expression<Bool>("write")
        /// If the group is allowed to create / remove media from the target pool
        let manage = Expression<Bool>("manage")

        /// Ensures the table exists
        init(db: Connection, t_groups: Groups) throws {
            VDebug("Ensuring 'grouppools' table...")
            // Setup the table
            try db.run(self.table.create(ifNotExists: true) {t in
                t.column(self.mpid)
                t.column(self.gid)
                t.column(self.quota)
                t.column(self.write)
                t.column(self.manage)

                t.primaryKey(self.mpid, self.gid)

                t.foreignKey(self.gid, references: t_groups.table, t_groups.gid)
            })
        }
    }
}
