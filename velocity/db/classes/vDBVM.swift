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
import Virtualization

/// The VM id (`VMID`) is an `Int64`
typealias VMID = Int64

extension VDB {
    /// A Virtual Machine
    class VM : Loggable {
        /// The logging context
        internal let context: String

        /// A reference to the velocity database for later use
        let db: VDB

        /// The unique id of this VM
        let vmid: VMID
        /// The unique name of the VM in the group
        let name: String
        /// The group this VM belongs to
        let group: Group
        /// The amount of CPUs this VM has available
        let cpu_count: UInt64
        /// The amount of memory this VM has
        let memory_size: UInt64
        /// If the `rosetta` translation layer should be enabled
        let rosetta: Bool
        /// If the VM should start automatically on Velocity startup
        let autostart: Bool

        init(db: VDB, info: Info) {
            self.context = "[vDB::VM (\(info.name))]"

            self.db = db

            self.vmid = info.vmid
            self.name = info.name
            self.group = info.group
            self.cpu_count = info.cpu_count
            self.memory_size = info.memory_size
            self.rosetta = info.rosetta
            self.autostart = info.autostart
        }

        struct Info {
            /// The unique id of this VM
            let vmid: VMID
            /// The unique name of the VM in the group
            let name: String
            /// The group this VM belongs to
            let group: Group
            /// The amount of CPUs this VM has available
            let cpu_count: UInt64
            /// The amount of memory this VM has
            let memory_size: UInt64
            /// If the `rosetta` translation layer should be enabled
            let rosetta: Bool
            /// If the VM should start automatically on Velocity startup
            let autostart: Bool
        }
    }
}
