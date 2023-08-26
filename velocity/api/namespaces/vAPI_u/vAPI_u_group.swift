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

        // Create a new group
        route.put() {req in
            let request: Structs.U.GROUP.PUT.Req = try req.content.decode(Structs.U.GROUP.PUT.Req.self)

            guard let key = self.get_authkey(authkey: request.authkey) else {
                return Response(status: .unauthorized)
            }

            let user = key.user

            guard let group = try self.db.group_select(gid: request.parent_gid) else {
                self.VDebug("\(user.info()) tried to create new group: parent group NOT FOUND")
                return Response(status: .notFound)
            }

            guard try user.has_permission(permission: "velocity.group.create", group: group) else {
                self.VDebug("\(user.info()) tried to create new group: FORBIDDEN")
                return Response(status: .forbidden)
            }

            var headers = HTTPHeaders()
            headers.add(name: .contentType, value: "application/json")

            switch try self.db.group_create(name: request.name, parent_gid: request.parent_gid) {
            case .failure(_):
                return Response(status: .conflict)
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
                return Response(status: .forbidden)
            }

            guard let delete_group = try self.db.group_select(gid: request.gid) else {
                self.VDebug("\(user.info()) tried to remove non-existing group {\(request.gid)}")
                return Response(status: .notFound)
            }

            try delete_group.delete()
            self.VDebug("\(user.info()) DELETED \(delete_group.info())")

            return Response(status: .ok)
        }
    }
}

extension VAPI.Structs.U {
    /// `/u/group`
    struct GROUP {
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
    }
}
