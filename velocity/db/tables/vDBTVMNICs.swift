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

        /// The possible modes for a NIC
        enum NICType : String, Decodable {
            case NAT = "NAT"
            case BRIDGE = "BRIDGE"
        }

        /// An error that can happen when inserting a NIC into the database
        enum InsertError {
            /// The `BRIDGE` NIC type requires a host NIC, but no one was provided
            case HostNICRequired
            /// The host NICID could not be found
            case HostNICNotFound
        }

        /// Insert a virtual NIC, attached to a virtual machine
        /// - Parameter db: The database to use for inserting
        /// - Parameter vm: The virtual machine to attach the NIC to
        /// - Parameter type: The type of NIC to use
        /// - Parameter host: A host NIC to use when `type` is `BRIDGE`
        /// - Returns: `false` if the operation could not be completed due to the `host` NIC missing
        func insert(db: VDB, vm: VM, type: NICType, host: NICID?) throws -> InsertError? {
            if type == .BRIDGE {
                guard let host = host else {
                    VErr("Inserting a NIC of type 'BRIDGE' requires a host NIC")
                    return .HostNICRequired
                }

                guard let _ = db.host_nic_get(nicid: host) else {
                    return .HostNICNotFound
                }
            }

            let query = self.table.insert(
                self.vmid <- vm.vmid,
                self.type <- type.rawValue,
                self.host <- host
            )

            try db.db.run(query);

            return nil
        }
    }

    /// Insert a virtual NIC, attached to a virtual machine
    /// - Parameter vm: The virtual machine to attach the NIC to
    /// - Parameter type: The type of NIC to use
    /// - Parameter host: A host NIC to use when `type` is `BRIDGE`
    /// - Returns: `false` if the operation could not be completed due to the `host` NIC missing
    func vmnic_insert(vm: VM, type: TVMNICs.NICType, host: NICID?) throws -> TVMNICs.InsertError? {
        return try self.t_vmnics.insert(db: self, vm: vm, type: type, host: host)
    }
}
