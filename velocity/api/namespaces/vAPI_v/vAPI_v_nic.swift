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
import Vapor

extension VAPI {
    /// Registers all endpoints within the namespace `/v/nic`
    func register_endpoints_v_nic(route: RoutesBuilder) throws {
        route.post("list") { req in
            let request: Structs.V.NIC.LIST.POST.Req = try req.content.decode(Structs.V.NIC.LIST.POST.Req.self)

            guard let key = self.get_authkey(authkey: request.authkey) else {
                return try self.error(code: .UNAUTHORIZED)
            }

            let c_user = key.user

            guard try c_user.has_permission(permission: "velocity.nic.list", group: nil) else {
                self.VDebug("\(c_user.info()) tried to list host NICs: FORBIDDEN")
                return try self.error(code: .V_NIC_LIST_POST_PERMISSION)
            }

            var host_nics: [Structs.V.NIC.LIST.POST.NICInfo] = []

            for nic in self.db.host_nic_list() {
                host_nics.append(Structs.V.NIC.LIST.POST.NICInfo(
                    nicid: nic.nicid,
                    description: nic.interface.description,
                    identifier: nic.interface.identifier))
            }

            self.VDebug("\(c_user.info()) listed host NICs: \(host_nics.count) available")

            return try self.response(Structs.V.NIC.LIST.POST.Res(host_nics: host_nics))
        }
    }
}

extension VAPI.Structs.V {
    /// `/v/nic`
    struct NIC {
        /// `/v/nic/list`
        struct LIST {
            /// `/v/nic/list` - POST
            struct POST {
                struct Req : Decodable {
                    let authkey: String
                }
                struct Res: Encodable {
                    let host_nics: [NICInfo]
                }
                struct NICInfo : Encodable {
                    let nicid: NICID
                    let description: String
                    let identifier: String
                }
            }
        }
    }
}
