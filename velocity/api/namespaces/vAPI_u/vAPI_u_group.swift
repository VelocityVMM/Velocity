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
import Vapor

extension VAPI {
    /// Registers all endpoints withing the namespace `/u/group`
    func register_endpoints_u_group(route: RoutesBuilder) throws {
        VDebug("Registering /u/group endpoints...")

        //
        // MARK: Group management /u/group
        //

        // Retrieve group information
        route
            .grouped(self.authenticator)
            .grouped(VDB.User.guardMiddleware())
            .post() { req in

            let c_user = try req.auth.require(VDB.User.self)
            let request: Structs.U.GROUP.POST.Req = try req.content.decode(Structs.U.GROUP.POST.Req.self)

            guard try c_user.has_permission(permission: "velocity.group.view", group: nil) else {
                self.VDebug("\(c_user.info()) requested group information for group \(request.gid): FORBIDDEN")
                return try self.error(code: .U_GROUP_POST_PERMISSION)
            }

            guard let group = try self.db.group_select(gid: request.gid) else {
                self.VDebug("\(c_user.info()) requested group information for group \(request.gid): NOT FOUND")
                return try self.error(code: .U_GROUP_POST_NOT_FOUND, "gid = \(request.gid)")
            }

            self.VDebug("\(c_user.info()) requested group information for \(group.info())")
            return try self.response(group)
        }

        // Create a new group
        route
            .grouped(self.authenticator)
            .grouped(VDB.User.guardMiddleware())
            .put() {req in

            let c_user = try req.auth.require(VDB.User.self)
            let request: Structs.U.GROUP.PUT.Req = try req.content.decode(Structs.U.GROUP.PUT.Req.self)

            guard let group = try self.db.group_select(gid: request.parent_gid) else {
                self.VDebug("\(c_user.info()) tried to create new group: parent group NOT FOUND")
                return try self.error(code: .U_GROUP_PUT_PARENT_NOT_FUND)
            }

            guard try c_user.has_permission(permission: "velocity.group.create", group: group) else {
                self.VDebug("\(c_user.info()) tried to create new group: FORBIDDEN")
                return try self.error(code: .U_GROUP_PUT_PERMISSION)
            }

            switch try self.db.group_create(name: request.name, parent_gid: request.parent_gid) {
            case .failure(_):
                return try self.error(code: .U_GROUP_PUT_CONFLICT)
            case .success(let new_group):
                self.VDebug("\(c_user.info()) CREATED \(new_group.info()), permissions: \(try c_user.get_permissions(group: new_group).count)")

                return try self.response(Structs.U.GROUP.PUT.Res(gid: new_group.gid, parent_gid: new_group.parent_gid, name: new_group.name))
            }
        }

        // Delete an existing group
        route
            .grouped(self.authenticator)
            .grouped(VDB.User.guardMiddleware())
            .delete() {req in

            let c_user = try req.auth.require(VDB.User.self)
            let request: Structs.U.GROUP.DELETE.Req = try req.content.decode(Structs.U.GROUP.DELETE.Req.self)

            guard try c_user.has_permission(permission: "velocity.group.remove", group: nil) else {
                self.VDebug("\(c_user.info()) tried to remove group: FORBIDDEN")
                return try self.error(code: .U_GROUP_DELETE_PERMISSION)
            }

            guard let delete_group = try self.db.group_select(gid: request.gid) else {
                self.VDebug("\(c_user.info()) tried to remove non-existing group {\(request.gid)}")
                return try self.error(code: .U_GROUP_DELETE_NOT_FOUND)
            }

            try delete_group.delete()
            self.VDebug("\(c_user.info()) DELETED \(delete_group.info())")

            return try self.response(nil)
        }

        // List all groups
        route
            .grouped(self.authenticator)
            .grouped(VDB.User.guardMiddleware())
            .post("list") { req in

            let c_user = try req.auth.require(VDB.User.self)

            // A fast lookup table for the groups added to the result array
            var groups_map: Dictionary<Int64, VDB.Group> = Dictionary()
            // The result array to transmit
            var groups: [VDB.Group.UserGroupInfo] = []

            // A cache array keeping groups that are yet to process
            var work = try c_user.get_groups_with_direct_permissions()

            while let cur_group = work.popLast() {

                // If the current group is already in the map, skip
                if groups_map[cur_group.gid] != nil {
                    continue
                }

                // If this group is not a root group, proceed with finding the parent group
                if cur_group.parent_gid != cur_group.gid {
                    // If the parent group is not in the map, add it to work and continue
                    if groups_map[cur_group.parent_gid] == nil {
                        guard let parent_group = try self.db.group_select(gid: cur_group.parent_gid) else {
                            self.VErr("FATAL: Assumed that parent group of \(cur_group) exists")
                            continue
                        }
                        work.append(cur_group)
                        work.append(parent_group)
                        continue
                    }
                }

                // If the user has any permissions on the current group, add its children to the work array
                if try c_user.count_permissions(group: cur_group) != 0 {
                    let child_groups = try cur_group.get_children(recursive: true)
                    work.insert(contentsOf: child_groups, at: 0)
                }

                groups_map[cur_group.gid] = cur_group
                groups.append(try cur_group.get_user_group_info(user: c_user))

            }

            self.VDebug("\(c_user.info()) requested group list, \(groups.count) groups")
            return try self.response(Structs.U.GROUP.LIST.POST.Res(groups: groups))
        }
    }
}

extension VAPI.Structs.U {
    /// `/u/group`
    struct GROUP {
        /// `/u/group` - POST
        struct POST {
            struct Req : Decodable {
                let gid: Int64
            }
        }
        /// `/u/group` - PUT
        struct PUT {
            struct Req : Codable {
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
                let gid: Int64
            }
        }

        /// `/u/group/list`
        struct LIST {
            /// `/u/group/list` - POST
            struct POST {
                struct Res : Encodable {
                    let groups: [VDB.Group.UserGroupInfo]
                }
            }
        }
    }
}
