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
    /// Registers all endpoints withing the namespace `/u/user`
    func register_endpoints_u_user(route: RoutesBuilder) throws {
        VDebug("Registering /u/user endpoints...")

        //
        // MARK: User management /u/user
        //

        // Create a new user
        route.put() {req in
            let request: Structs.U.USER.PUT.Req = try req.content.decode(Structs.U.USER.PUT.Req.self)

            guard let key = self.get_authkey(authkey: request.authkey) else {
                return Response(status: .unauthorized)
            }

            let user = key.user

            guard try user.has_permission(permission: "velocity.user.create", group: nil) else {
                self.VDebug("\(user.info()) tried to create new user: FORBIDDEN")
                return Response(status: .forbidden)
            }

            guard try !self.db.user_exists(username: request.name) else {
                self.VDebug("\(user.info()) tried to create duplicate user '\(request.name)'")
                return Response(status: .conflict)
            }

            let new_user = try self.db.user_create(username: request.name, password: request.password).get()
            let response = VAPI.Structs.U.USER.PUT.Res(uid: new_user.uid, name: new_user.username)
            self.VDebug("\(user.info()) CREATED \(new_user.info())")

            var headers = HTTPHeaders()
            headers.add(name: .contentType, value: "application/json")

            return try Response(status: .ok, headers: headers, body: .init(data: self.encoder.encode(response)))
        }

        // Delete an existing user
        route.delete() {req in
            let request: Structs.U.USER.DELETE.Req = try req.content.decode(Structs.U.USER.DELETE.Req.self)

            guard let key = self.get_authkey(authkey: request.authkey) else {
                return Response(status: .unauthorized)
            }

            let user = key.user

            guard try user.has_permission(permission: "velocity.user.remove", group: nil) else {
                self.VDebug("\(user.info()) tried to create new user: FORBIDDEN")
                return Response(status: .forbidden)
            }

            guard let delete_user = try self.db.user_select(uid: request.uid) else {
                self.VDebug("\(user.info()) tried to create non-existing user {\(request.uid)}")
                return Response(status: .notFound)
            }

            try delete_user.delete()
            self.VDebug("\(user.info()) DELETED \(delete_user.info())")

            return Response(status: .ok)
        }
    }
}

extension VAPI.Structs.U {
    /// `/u/user`
    struct USER {
        /// `/u/user` - PUT
        struct PUT {
            struct Req : Codable {
                let authkey: String
                let name: String
                let password: String
            }
            struct Res : Codable {
                let uid: Int64
                let name: String
            }
        }
        /// `/u/user` - DELETE
        struct DELETE {
            struct Req : Codable {
                let authkey: String
                let uid: Int64
            }
        }
        /// `/u/user/groups` - GET
        struct GROUPS {
            struct Req : Codable {
                let authkey: String
            }
            struct Res : Codable {
                let uid: Int64
                let groups: [GroupInfo]

                struct GroupInfo : Codable {
                    let gid: Int64
                    let name: String
                    let permissions: [String]
                    let parent_gid: Int64
                }
            }
        }
    }
}
