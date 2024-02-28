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
import Virtualization

extension VZ {

    /// A NIC configuration that can be converted to a `VZNetworkDeviceConfiguration`
    enum NICConfiguration : Encodable {

        /// A NAT NIC
        case NAT
        /// Use a bridged host NIC
        case BRIDGE(VDB.HostNIC)

        /// Generates a `VZNetworkDeviceConfiguration` from this configuration
        func get_network_device_configuration() -> VZNetworkDeviceConfiguration {
            let configuration = VZVirtioNetworkDeviceConfiguration()

            switch self {
            case .NAT:
                configuration.attachment = VZNATNetworkDeviceAttachment()
            case .BRIDGE(let host_nic):
                configuration.attachment = VZBridgedNetworkDeviceAttachment(interface: host_nic.interface)
            }

            return configuration
        }

        /// Provide coding keys for encoding this type
        enum CodingKeys: String, CodingKey {
            case type
            case host
        }

        /// Implement `Encodable`
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .NAT:
                try container.encode("NAT", forKey: .type)
            case .BRIDGE(let host):
                try container.encode("BRIDGE", forKey: .type)
                try container.encode(host.nicid, forKey: .host)
            }
        }
    }
}
