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
// SOFTWARE.`
//

import Foundation
import SQLite

extension VDB {
    /// The `vms` table, storing all virtual machines
    class TVMs : Loggable {
        /// The logging context
        internal let context: String = "[vDB::VMs]"

        /// The `vms` table
        let table = Table("vms")

        /// The unique `vmid`
        let vmid = Expression<VMID>("vmid")
        /// A unique name within the group for this VM
        let name = Expression<String>("name")
        /// The `gid` of the group this VM belongs to
        let gid = Expression<GID>("gid")
        /// The amount of CPU cores the VM gets
        let cpus = Expression<Int64>("cpus")
        /// The amount of memory in MiB the VM gets
        let memory_mib = Expression<Int64>("memory_mib")
        /// If the `Rosetta` translation layer should be enabled
        let rosetta = Expression<Bool>("rosetta")
        /// If the VM should start automatically on Velocity startup
        let autostart = Expression<Bool>("autostart")

        /// Ensures the table exists
        init(db: Connection, t_groups: Groups) throws {
            VDebug("Ensuring 'vms' table...")
            // Setup the table
            try db.run(self.table.create(ifNotExists: true) {t in
                t.column(self.vmid, primaryKey: true)
                t.column(self.name)
                t.column(self.gid)
                t.column(self.cpus)
                t.column(self.memory_mib)
                t.column(self.rosetta)
                t.column(self.autostart)

                t.unique(self.vmid, self.name)

                t.foreignKey(self.gid, references: t_groups.table, t_groups.gid, update: .cascade, delete: .cascade)
            })
        }

        /// Insert a virtual macine into the database using the provided information
        /// - Parameter db: The database to use for inserting
        /// - Parameter info: Information about the virtual machine to insert
        func insert(db: VDB, info: VM.Info) throws -> VM {
            let query = self.table.insert(
                self.name <- info.name,
                self.gid <- info.group.gid,
                self.cpus <- Int64(info.cpu_count),
                self.memory_mib <- Int64(info.memory_size_mib),
                self.rosetta <- info.rosetta,
                self.autostart <- info.autostart
            )

            let vmid = try db.db.run(query);

            return VM(db: db, vmid: vmid, info: info)
        }

        /// Retrieve all VMs that are stored in this database
        func get_all_vms(db: VDB) throws -> [VM] {
            var vms: [VM] = []

            for row in try db.db.prepare(self.table) {
                guard let vm = try VM.from_row(db: db, row: row) else {
                    continue
                }

                vms.append(vm)
            }

            return vms
        }

        /// Retrieve all VMs that have the `autostart` field set to `true`
        func get_autostart_vms(db: VDB) throws -> [VM] {
            let query = self.table.where(self.autostart == true)

            var vms: [VM] = []

            for row in try db.db.prepare(query) {
                guard let vm = try VM.from_row(db: db, row: row) else {
                    continue
                }

                vms.append(vm)
            }

            return vms
        }
    }

    /// Insert a virtual macine into the database using the provided information
    /// - Parameter info: Information about the virtual machine to insert
    func vm_insert(info: VM.Info) throws -> VM {
        return try self.t_vms.insert(db: self, info: info)
    }

    /// Selects all VMs that have the `autostart` field set to `true`
    func vms_get_autostart_vms() throws -> [VM] {
        return try self.t_vms.get_autostart_vms(db: self)
    }

    /// Retrieve all VMs that are stored in this database
    func vms_get_all_vms() throws -> [VM] {
        return try self.t_vms.get_all_vms(db: self)
    }
}
