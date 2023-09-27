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
    /// The `vmnics` table, connecting NICs to virtual machines
    class TVMNICs : Loggable {
        /// The logging context
        internal let context: String = "[vDB::VMNICs]"

        /// The `vmnics` table
        let table = Table("vmnics")

        /// The `vmid` of the VM this NIC is attached to
        let vmid = Expression<VMID>("vmid")
        /// The type of NIC this is (`NAT`, `BRIDGE`)
        let type = Expression<String>("type")
        /// If the `type` is `BRIDGE`, this is the host `NICID`
        let host = Expression<NICID?>("host")

        /// Ensures the table exists
        init(db: Connection, t_vms: TVMs) throws {
            VDebug("Ensuring 'vmnics' table...")
            // Setup the table
            try db.run(self.table.create(ifNotExists: true) {t in
                t.column(self.vmid)
                t.column(self.type)
                t.column(self.host)

                t.foreignKey(self.vmid, references: t_vms.table, t_vms.vmid)
            })
        }
    }
}
