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
    /// Registers all endpoints withing the namespace `/m/pool`
    func register_endpoints_m_pool(route: RoutesBuilder) throws {

        route.put("assign") { req in
            let request: Structs.M.POOL.ASSIGN.PUT.Req = try req.content.decode(Structs.M.POOL.ASSIGN.PUT.Req.self)

            guard let key = self.get_authkey(authkey: request.authkey) else {
                return try self.error(code: .UNAUTHORIZED)
            }

            let user = key.user

            guard try user.has_permission(permission: "velocity.pool.assign", group: nil) else {
                self.VDebug("\(user.info()) tried to assign group (\(request.gid)) to pool (\(request.mpid)): FORBIDDEN")
                return try self.error(code: .M_POOL_ASSIGN_PUT_PERMISSION)
            }

            guard let group = try self.db.group_select(gid: request.gid) else {
                self.VDebug("\(user.info()) tried to assign group (\(request.gid)) to pool (\(request.mpid)): GROUP NOT FOUND")
                return try self.error(code: .M_POOL_ASSIGN_PUT_GROUP_NOT_FOUND)
            }

            guard let pool = self.db.pool_get(mpid: request.mpid) else {
                self.VDebug("\(user.info()) tried to assign \(group.info()) to pool (\(request.mpid)): MEDIAPOOL NOT FOUND")
                return try self.error(code: .M_POOL_ASSIGN_PUT_MEDIAPOOL_NOT_FOUND)
            }

            try pool.assign(db: self.db, group: group, quota: request.quota, write: request.write, manage: request.write)
            self.VDebug("\(user.info()) assigned \(group.info()) to pool (\(pool.name)): write: \(request.write), manage: \(request.manage)")

            return try self.response(nil)
        }

        route.delete("assign") { req in
            let request: Structs.M.POOL.ASSIGN.DELETE.Req = try req.content.decode(Structs.M.POOL.ASSIGN.DELETE.Req.self)

            guard let key = self.get_authkey(authkey: request.authkey) else {
                return try self.error(code: .UNAUTHORIZED)
            }

            let user = key.user

            guard try user.has_permission(permission: "velocity.pool.revoke", group: nil) else {
                self.VDebug("\(user.info()) tried to revoke group (\(request.gid)) from pool (\(request.mpid)): FORBIDDEN")
                return try self.error(code: .M_POOL_ASSIGN_DELETE_PERMISSION)
            }

            guard let group = try self.db.group_select(gid: request.gid) else {
                self.VDebug("\(user.info()) tried to revoke group (\(request.gid)) from pool (\(request.mpid)): GROUP NOT FOUND")
                return try self.error(code: .M_POOL_ASSIGN_PUT_GROUP_NOT_FOUND)
            }

            guard let pool = self.db.pool_get(mpid: request.mpid) else {
                self.VDebug("\(user.info()) tried to revoke \(group.info()) from pool (\(request.mpid)): MEDIAPOOL NOT FOUND")
                return try self.error(code: .M_POOL_ASSIGN_PUT_MEDIAPOOL_NOT_FOUND)
            }

            try pool.revoke(db: self.db, group: group)
            self.VDebug("\(user.info()) revoked \(group.info()) from pool (\(pool.name))")

            return try self.response(nil)
        }

        route.post("list") { req in
            let request: Structs.M.POOL.LIST.POST.Req = try req.content.decode(Structs.M.POOL.LIST.POST.Req.self)

            guard let key = self.get_authkey(authkey: request.authkey) else {
                return try self.error(code: .UNAUTHORIZED)
            }

            let user = key.user

            guard try user.has_permission(permission: "velocity.pool.list", group: nil) else {
                self.VDebug("\(user.info()) tried to list available pools: FORBIDDEN")
                return try self.error(code: .M_POOL_LIST_POST_PERMISSION)
            }

            guard let group = try self.db.group_select(gid: request.gid) else {
                self.VDebug("\(user.info()) tried to list pools of group (\(request.gid)): GROUP NOT FOUND")
                return try self.error(code: .M_POOL_LIST_POST_GROUP_NOT_FOUND)
            }

            let pools = try group.get_mediapools_info()
            self.VDebug("\(user.info()) requested mediapool list: \(pools.count) pools")

            return try self.response(Structs.M.POOL.LIST.POST.Res(pools: pools))
        }
    }
}

extension VAPI.Structs.M {
    /// `/m/pool`
    struct POOL {
        /// `/m/pool/assign`
        struct ASSIGN {
            /// `/m/pool/assign` - PUT
            struct PUT {
                struct Req : Decodable {
                    let authkey: String
                    let gid: GID
                    let mpid: MPID
                    let quota: Int64
                    let write: Bool
                    let manage: Bool
                }
            }
            /// `/m/pool/assign` - DELETE
            struct DELETE {
                struct Req : Decodable {
                    let authkey: String
                    let gid: GID
                    let mpid: MPID
                }
            }
        }

        /// `/m/pool/list`
        struct LIST {
            /// `/m/pool/list` - POST
            struct POST {
                struct Req : Decodable {
                    let authkey: String
                    let gid: GID
                }
                struct Res : Encodable {
                    let pools: [VDB.MediaPool.Info]
                }
            }
        }
    }
}
