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

/// The NIC id (`NICID`) is an `Int64`
typealias NICID = Int64

extension VDB {
    /// A host NIC, defined by the administrator
    class HostNIC : Loggable {
        /// The logging context
        internal let context: String

        /// The NIC id
        let nicid: NICID
        /// The interface to use when bridging
        let interface: VZBridgedNetworkInterface

        /// Creates a new pool
        /// - Parameter nicid: The unique `NICID`
        /// - Parameter interface: The interface to use for bridging
        init(nicid: NICID, interface: VZBridgedNetworkInterface) {
            self.context = "[vDB::HostNIC (\(interface.description))]"

            self.nicid = nicid
            self.interface = interface
            VInfo("Created new HostNIC for bridging")
        }
    }

    /// Add a host NIC to the database
    /// - Parameter nic: The NIC to add
    func host_nic_add(_ nic: HostNIC) {
        self.host_nics[nic.nicid] = nic
    }

    /// Get a host NIC from the database
    /// - Parameter nicid: The `NICID` to search for
    /// - Returns: The NIC if found, else `nil`
    func host_nic_get(nicid: NICID) -> HostNIC? {
        return self.host_nics[nicid]
    }

    /// List all available host NICs
    func host_nic_list() -> [HostNIC] {
        var res: [HostNIC] = []

        for entry in self.host_nics {
            res.append(entry.value)
        }

        return res
    }
}
