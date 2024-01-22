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
    /// The `vmdisplays` table, connecting displays to virtual machines
    class TVMDisplays : Loggable {
        /// The logging context
        internal let context: String = "[vDB::VMDisplays]"

        /// The `vmdisplays` table
        let table = Table("vmdisplays")

        /// The `vmid` of the VM this display is attached to
        let vmid = Expression<VMID>("vmid")
        /// A unique name for the display for this VM
        let name = Expression<String>("name")
        /// The width of the screen
        let width = Expression<Int64>("width")
        /// The height of the screen
        let height = Expression<Int64>("height")
        /// The pixel density in pixels per inch
        let ppi = Expression<Int64>("ppi")

        /// Ensures the table exists
        init(db: Connection, t_vms: TVMs) throws {
            VDebug("Ensuring 'vmdisplays' table...")
            // Setup the table
            try db.run(self.table.create(ifNotExists: true) {t in
                t.column(self.vmid)
                t.column(self.name)
                t.column(self.width)
                t.column(self.height)
                t.column(self.ppi)

                t.primaryKey(self.vmid, self.name)

                t.foreignKey(self.vmid, references: t_vms.table, t_vms.vmid)
            })
        }

        /// Inserts a new display into the database
        /// - Parameter db: The database connection to use
        /// - Parameter vm: The virtual machine to attach the display to
        /// - Parameter name: The name for the new display
        /// - Parameter width: The width of the display in pixels
        /// - Parameter height: The height of the display in pixels
        /// - Parameter ppi: The pixels per inch of the display
        /// - Returns: `false` if the display is a duplicate, else `true`
        func insert(db: VDB, vm: VM, name: String, width: Int64, height: Int64, ppi: Int64) throws -> Bool {
            if try db.db.exists(self.table, self.vmid == vm.vmid && self.name == name) {
                return false;
            }

            let query = self.table.insert(
                self.vmid <- vm.vmid,
                self.name <- name,
                self.width <- width,
                self.height <- height,
                self.ppi <- ppi
            )

            try db.db.run(query)

            return true
        }

        /// Selects all display configurations for a virtual machine
        /// - Parameter vm: The VM to select the displays of
        func select_vm_displays(vm: VM) throws -> [VZ.DisplayConfiguration] {
            let query = self.table.filter(self.vmid == vm.vmid)
            var res: [VZ.DisplayConfiguration] = []

            for row in try vm.db.db.prepare(query) {
                res.append(self.display_from_row(row: row))
            }

            return res
        }

        /// Creates a `VZ.DisplayConfiguration` from a provided database row
        func display_from_row(row: Row) -> VZ.DisplayConfiguration {
            return VZ.DisplayConfiguration(
                name: row[self.name],
                width: row[self.width],
                height: row[self.height],
                ppi: row[self.ppi])
        }
    }

    /// Inserts a new display into the database
    /// - Parameter vm: The virtual machine to attach the display to
    /// - Parameter name: The name for the new display
    /// - Parameter width: The width of the display in pixels
    /// - Parameter height: The height of the display in pixels
    /// - Parameter ppi: The pixels per inch of the display
    /// - Returns: `false` if the display is a duplicate, else `true`
    func display_insert(vm: VM, name: String, width: Int64, height: Int64, ppi: Int64) throws -> Bool {
        return try self.t_vmdisplays.insert(db: self, vm: vm, name: name, width: width, height: height, ppi: ppi)
    }
}
