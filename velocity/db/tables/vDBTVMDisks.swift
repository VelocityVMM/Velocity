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
    /// The `vmdisks` table, connecting disks to virtual machines
    class TVMDisks : Loggable {
        /// The logging context
        internal let context: String = "[vDB::VMDisks]"

        /// The `vmdisks` table
        let table = Table("vmdisks")

        /// The `vmid` of the VM this media is attached to
        let vmid = Expression<VMID>("vmid")
        /// The `mid` of the media to attach
        let mid = Expression<MID>("mid")
        /// The attachment mode (`USB`, `BLOCK`...)
        let mode = Expression<String>("mode")
        /// If the attachment should be read-only
        let readonly = Expression<Bool>("readonly")

        /// Ensures the table exists
        init(db: Connection, t_vms: TVMs, t_media: TMedia) throws {
            VDebug("Ensuring 'vmdisks' table...")
            // Setup the table
            try db.run(self.table.create(ifNotExists: true) {t in
                t.column(self.vmid)
                t.column(self.mid)
                t.column(self.mode)
                t.column(self.readonly)

                t.primaryKey(self.vmid, self.mid)

                t.foreignKey(self.vmid, references: t_vms.table, t_vms.vmid)
                t.foreignKey(self.mid, references: t_media.table, t_media.mid)
            })
        }

        /// Inserts a new disk into the database
        /// - Parameter vm: The virtual machine to attach the diplay to
        /// - Parameter media: The media this disk wraps
        /// - Parameter mode: The attachment mode for the disk
        /// - Parameter readonly: If the disk should be read-only for this virtual machine
        func insert(vm: VM, media: Media, mode: DiskMode, readonly: Bool) throws {
            let query = self.table.insert(or: .replace,
                self.vmid <- vm.vmid,
                self.mid <- media.mid,
                self.mode <- mode.rawValue,
                self.readonly <- readonly)

            try vm.db.db.run(query)
        }

        /// All possible modes a disk can be attached
        enum DiskMode : String, Decodable {
            case USB = "USB"
            case VIRTIO = "VIRTIO"

            static func parse(_ str: String) -> DiskMode? {
                switch str {
                case "USB": return .USB
                case "VIRTIO": return .VIRTIO
                default: return nil
                }
            }
        }
    }

    /// Inserts a new disk into the database
    /// - Parameter vm: The virtual machine to attach the diplay to
    /// - Parameter media: The media this disk wraps
    /// - Parameter mode: The attachment mode for the disk
    /// - Parameter readonly: If the disk should be read-only for this virtual machine
    func disk_insert(vm: VM, media: Media, mode: TVMDisks.DiskMode, readonly: Bool) throws {
        return try self.t_vmdisks.insert(vm: vm, media: media, mode: mode, readonly: readonly)
    }
}
