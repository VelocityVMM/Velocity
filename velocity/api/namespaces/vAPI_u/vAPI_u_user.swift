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
                return try self.error(code: .UNAUTHORIZED)
            }

            let user = key.user

            guard try user.has_permission(permission: "velocity.user.create", group: nil) else {
                self.VDebug("\(user.info()) tried to create new user: FORBIDDEN")
                return try self.error(code: .U_USER_PUT_PERMISSION)
            }

            guard try !self.db.user_exists(username: request.name) else {
                self.VDebug("\(user.info()) tried to create duplicate user '\(request.name)'")
                return try self.error(code: .U_USER_PUT_CONFLICT)
            }

            let new_user = try self.db.user_create(username: request.name, password: request.password).get()
            self.VDebug("\(user.info()) CREATED \(new_user.info())")


            return try self.response(Structs.U.USER.PUT.Res(uid: new_user.uid, name: new_user.username))
        }

        // Delete an existing user
        route.delete() {req in
            let request: Structs.U.USER.DELETE.Req = try req.content.decode(Structs.U.USER.DELETE.Req.self)

            guard let key = self.get_authkey(authkey: request.authkey) else {
                return try self.error(code: .UNAUTHORIZED)
            }

            let user = key.user

            guard try user.has_permission(permission: "velocity.user.remove", group: nil) else {
                self.VDebug("\(user.info()) tried to remove user: FORBIDDEN")
                return try self.error(code: .U_USER_DELETE_PERMISSION)
            }

            guard let delete_user = try self.db.user_select(uid: request.uid) else {
                self.VDebug("\(user.info()) tried to remove non-existing user {\(request.uid)}")
                return try self.error(code: .U_USER_DELETE_NOT_FOUND, "uid = \(request.uid)")
            }

            try delete_user.delete()
            self.VDebug("\(user.info()) DELETED \(delete_user.info())")

            return try self.response(nil, status: .ok)
        }

        route.post() { req in
            let request: Structs.U.USER.POST.Req = try req.content.decode(Structs.U.USER.POST.Req.self)

            guard let key = self.get_authkey(authkey: request.authkey) else {
                return try self.error(code: .UNAUTHORIZED)
            }

            let c_user = key.user

            guard let uid = request.uid else {
                self.VDebug("\(c_user.info()) requested user information")
                return try self.response(c_user)
            }

            guard try c_user.has_permission(permission: "velocity.user.view", group: nil) else {
                self.VDebug("\(c_user.info()) requested user information for user \(uid): FORBIDDEN")
                return try self.error(code: .U_USER_POST_PERMISSION)
            }

            guard let user = try self.db.user_select(uid: uid) else {
                self.VDebug("\(c_user.info()) requested user information for user \(uid): NOT FOUND")
                return try self.error(code: .U_USER_POST_NOT_FOUND, "uid = \(uid)")
            }

            self.VDebug("\(c_user.info()) requested user information for \(user.info())")
            return try self.response(user)
        }

        route.post("list") { req in
            let request: Structs.U.USER.LIST.POST.Req = try req.content.decode(Structs.U.USER.LIST.POST.Req.self)

            guard let key = self.get_authkey(authkey: request.authkey) else {
                return try self.error(code: .UNAUTHORIZED)
            }

            let c_user = key.user

            guard try c_user.has_permission(permission: "velocity.user.list", group: nil) else {
                self.VDebug("\(c_user.info()) tried to list users: FORBIDDEN")
                return try self.error(code: .U_USER_POST_PERMISSION)
            }

            var users: [Structs.U.USER.LIST.POST.UserInfo] = []

            for u in try self.db.user_list() {
                users.append(Structs.U.USER.LIST.POST.UserInfo(uid: u.uid, name: u.username))
            }

            self.VDebug("\(c_user.info()) requested user list")
            return try self.response(Structs.U.USER.LIST.POST.Res(users: users))
        }

        //
        // MARK: Permission management /u/user/permission
        //

        let permissions = route.grouped("permission")

        // Add new permissions
        permissions.put() { req in
            let request: Structs.U.USER.PERMISSION.PUT.Req = try req.content.decode(Structs.U.USER.PERMISSION.PUT.Req.self)

            guard let key = self.get_authkey(authkey: request.authkey) else {
                return try self.error(code: .UNAUTHORIZED)
            }

            let c_user = key.user

            // First check if the user has the permission to assign
            guard try c_user.has_permission(permission: "velocity.user.assign", group: nil) else {
                self.VDebug("\(c_user.info()) tried to assign '\(request.permission)' to user \(request.uid) on group \(request.gid): FORBIDDEN")
                return try self.error(code: .U_USER_PERMISSION_PUT_PERMISSION)
            }

            // Select the user
            guard let user = try self.db.user_select(uid: request.uid) else {
                self.VDebug("\(c_user.info()) tried to assign '\(request.permission)' to user \(request.uid) on group \(request.gid): USER NOT FOUND")
                return try self.error(code: .U_USER_PERMISSION_PUT_USER_NOT_FOUND)
            }

            // Select the group
            guard let group = try self.db.group_select(gid: request.gid) else {
                self.VDebug("\(c_user.info()) tried to assign '\(request.permission)' to \(user.info()) on group \(request.gid): GROUP NOT FOUND")
                return try self.error(code: .U_USER_PERMISSION_PUT_GROUP_NOT_FOUND)
            }

            // Select the permission
            guard let permission = try self.db.permission_select(name: request.permission) else {
                self.VDebug("\(c_user.info()) tried to assign non-existing permission \(request.permission)")
                return try self.error(code: .U_USER_PERMISSION_PUT_PERMISSION_NOT_FOUND)
            }

            // Check if the calling user has the permission
            guard try c_user.has_permission(permission: request.permission, group: group) else {
                self.VDebug("\(c_user.info()) tried to assign '\(request.permission)' to \(user.info()) on \(group.info()): FORBIDDEN (TOO HIGH)")
                return try self.error(code: .U_USER_PERMISSION_PUT_HIGHER_PERMISSION)
            }

            // Assign the permission
            try user.add_permission(group: group, permission: permission)

            return try self.response(nil)
        }

        // Remove a permission
        permissions.delete() { req in
            let request: Structs.U.USER.PERMISSION.DELETE.Req = try req.content.decode(Structs.U.USER.PERMISSION.DELETE.Req.self)

            guard let key = self.get_authkey(authkey: request.authkey) else {
                return try self.error(code: .UNAUTHORIZED)
            }

            let c_user = key.user

            // First check if the user has the permission to revoke
            guard try c_user.has_permission(permission: "velocity.user.revoke", group: nil) else {
                self.VDebug("\(c_user.info()) tried to revoke permissions from user \(request.uid) on group \(request.gid): FORBIDDEN")
                return try self.error(code: .U_USER_PERMISSION_DELETE_PERMISSION)
            }

            // Retrieve the user from the database
            guard let user = try self.db.user_select(uid: request.uid) else {
                self.VDebug("\(c_user.info()) tried to revoke permissions from user \(request.uid) on group \(request.gid): USER NOT FOUND")
                return try self.error(code: .U_USER_PERMISSION_DELETE_USER_NOT_FOUND)
            }

            // Retrieve the group from the database
            guard let group = try self.db.group_select(gid: request.gid) else {
                self.VDebug("\(c_user.info()) tried to revoke permissions from user \(request.uid) on group \(request.gid): GROUP NOT FOUND")
                return try self.error(code: .U_USER_PERMISSION_DELETE_GROUP_NOT_FOUND)
            }

            // Remove the permissions
            let ok = try user.remove_permission(group: group, permission_name: request.permission)

            if ok {
                return try self.response(nil)
            } else {
                return try self.error(code: .U_USER_PERMISSION_DELETE_PERMISSION_NOT_FOUND)
            }
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
        /// `/u/user` - POST
        struct POST {
            struct Req : Codable {
                let authkey: String
                let uid: Int64?
            }
        }

        /// `/u/user/list`
        struct LIST {
            /// `/u/user/list` - POST
            struct POST {
                struct Req : Decodable {
                    let authkey: String
                }
                struct Res : Encodable {
                    let users: [UserInfo]
                }
                struct UserInfo : Encodable {
                    let uid: Int64
                    let name: String
                }
            }
        }

        /// `/u/user/permission`
        struct PERMISSION {
            /// `/u/user/permission` - PUT
            struct PUT {
                struct Req : Codable {
                    let authkey: String
                    let uid: Int64
                    let gid: Int64
                    let permission: String
                }
            }
            /// `/u/user/permission` - DELETE
            struct DELETE {
                struct Req : Decodable {
                    let authkey: String
                    let uid: Int64
                    let gid: Int64
                    let permission: String?
                }
            }
        }
    }
}
