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
    /// Registers all endpoints withing the namespace `/u/group`
    func register_endpoints_u_group(route: RoutesBuilder) throws {
        VDebug("Registering /u/group endpoints...")

        //
        // MARK: Group management /u/group
        //

        // Retrieve group information
        route.post() { req in
            let request: Structs.U.GROUP.POST.Req = try req.content.decode(Structs.U.GROUP.POST.Req.self)

            guard let key = self.get_authkey(authkey: request.authkey) else {
                return Response(status: .unauthorized)
            }

            var headers = HTTPHeaders()
            headers.add(name: .contentType, value: "application/json")

            let c_user = key.user

            guard try c_user.has_permission(permission: "velocity.group.view", group: nil) else {
                self.VDebug("\(c_user.info()) requested group information for group \(request.gid): FORBIDDEN")
                return try self.error(code: .U_GROUP_POST_PERMISSION)
            }

            guard let group = try self.db.group_select(gid: request.gid) else {
                self.VDebug("\(c_user.info()) requested group information for group \(request.gid): NOT FOUND")
                return try self.error(code: .U_GROUP_POST_NOT_FOUND, "gid = \(request.gid)")
            }

            self.VDebug("\(c_user.info()) requested group information for \(group.info())")
            return try Response(status: .ok, headers: headers, body: .init(data: self.encoder.encode(group)))
        }

        // Create a new group
        route.put() {req in
            let request: Structs.U.GROUP.PUT.Req = try req.content.decode(Structs.U.GROUP.PUT.Req.self)

            guard let key = self.get_authkey(authkey: request.authkey) else {
                return Response(status: .unauthorized)
            }

            let user = key.user

            guard let group = try self.db.group_select(gid: request.parent_gid) else {
                self.VDebug("\(user.info()) tried to create new group: parent group NOT FOUND")
                return try self.error(code: .U_GROUP_PUT_PARENT_NOT_FUND)
            }

            guard try user.has_permission(permission: "velocity.group.create", group: group) else {
                self.VDebug("\(user.info()) tried to create new group: FORBIDDEN")
                return try self.error(code: .U_GROUP_PUT_PERMISSION)
            }

            var headers = HTTPHeaders()
            headers.add(name: .contentType, value: "application/json")

            switch try self.db.group_create(name: request.name, parent_gid: request.parent_gid) {
            case .failure(_):
                return try self.error(code: .U_GROUP_PUT_CONFLICT)
            case .success(let new_group):
                let response = VAPI.Structs.U.GROUP.PUT.Res(gid: new_group.gid, parent_gid: new_group.parent_gid, name: new_group.name)
                self.VDebug("\(user.info()) CREATED \(new_group.info()), permissions: \(try user.get_permissions(group: new_group).count)")

                return try Response(status: .ok, headers: headers, body: .init(data: self.encoder.encode(response)))
            }
        }

        // Delete an existing group
        route.delete() {req in
            let request: Structs.U.GROUP.DELETE.Req = try req.content.decode(Structs.U.GROUP.DELETE.Req.self)

            guard let key = self.get_authkey(authkey: request.authkey) else {
                return Response(status: .unauthorized)
            }

            let user = key.user

            guard try user.has_permission(permission: "velocity.group.remove", group: nil) else {
                self.VDebug("\(user.info()) tried to remove group: FORBIDDEN")
                return try self.error(code: .U_GROUP_DELETE_PERMISSION)
            }

            guard let delete_group = try self.db.group_select(gid: request.gid) else {
                self.VDebug("\(user.info()) tried to remove non-existing group {\(request.gid)}")
                return try self.error(code: .U_GROUP_DELETE_NOT_FOUND)
            }

            try delete_group.delete()
            self.VDebug("\(user.info()) DELETED \(delete_group.info())")

            return Response(status: .ok)
        }

        // List all groups
        route.post("list") { req in
            let request: Structs.U.GROUP.LIST.POST.Req = try req.content.decode(Structs.U.GROUP.LIST.POST.Req.self)

            guard let key = self.get_authkey(authkey: request.authkey) else {
                return Response(status: .unauthorized)
            }

            let c_user = key.user

            guard try c_user.has_permission(permission: "velocity.group.list", group: nil) else {
                self.VDebug("\(c_user.info()) tried to list groups: FORBIDDEN")
                return try self.error(code: .U_GROUP_LIST_POST_PERMISSION)
            }

            var groups: [Structs.U.GROUP.LIST.POST.GroupInfo] = []

            for group in try self.db.group_list() {
                groups.append(Structs.U.GROUP.LIST.POST.GroupInfo(gid: group.gid, parent_gid: group.parent_gid, name: group.name))
            }

            let response = Structs.U.GROUP.LIST.POST.Res(groups: groups)

            var headers = HTTPHeaders()
            headers.add(name: .contentType, value: "application/json")

            self.VDebug("\(c_user.info()) requested group list")
            return try Response(status: .ok, headers: headers, body: .init(data: self.encoder.encode(response)))
        }
    }
}

extension VAPI.Structs.U {
    /// `/u/group`
    struct GROUP {
        /// `/u/group` - POST
        struct POST {
            struct Req : Decodable {
                let authkey: String
                let gid: Int64
            }
        }
        /// `/u/group` - PUT
        struct PUT {
            struct Req : Codable {
                let authkey: String
                let parent_gid: Int64
                let name: String
            }
            struct Res : Codable {
                let gid: Int64
                let parent_gid: Int64
                let name: String
            }
        }
        /// `/u/group` - DELETE
        struct DELETE {
            struct Req : Codable {
                let authkey: String
                let gid: Int64
            }
        }

        /// `/u/group/list`
        struct LIST {
            /// `/u/group/list` - POST
            struct POST {
                struct Req : Decodable {
                    let authkey: String
                }
                struct Res : Encodable {
                    let groups: [GroupInfo]
                }
                struct GroupInfo : Encodable {
                    let gid: Int64
                    let parent_gid: Int64
                    let name: String
                }
            }
        }
    }
}
