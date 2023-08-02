//
//  vAPI_U.swift
//  velocity
//
//  Created by Max Kofler on 31/07/23.
//

import Foundation
import Vapor

extension VAPI {
    func register_endpoints_u() throws {
        VDebug("Ensuring API base...")

        // Ensure the root user and group
        let u_root = try self.db.user_ensure(username: "root", password: "root", uid: 0).get()
        let g_root = try self.db.group_ensure(groupname: "root", gid: 0).get()
        try u_root.join_group(group: g_root)

        // Ensure special groups
        let _ = try self.db.group_ensure(groupname: "usermanager").get()

        VDebug("Registering /u endpoints...")

        //
        // MARK: Authentication /u/auth
        //

        // Authenticate for a new authkey
        self.app.post("u", "auth") { req in
            let request: Structs.U.AUTH.POST.Req = try req.content.decode(Structs.U.AUTH.POST.Req.self)

            var headers = HTTPHeaders()
            headers.add(name: .contentType, value: "application/json")

            // Get the user
            guard let user = { () -> VDB.User? in
                do {
                    let user = try self.db.user_select(username: request.username)

                    guard let user = user else {
                        self.VErr("User \(request.username) not found")
                        return nil
                    }

                    if user.pwhash != VDB.hash_pw(request.password) {
                        self.VErr("Password for user \(request.username) does not match")
                        return nil
                    }

                    return user
                } catch {
                    return nil
                }
            }() else {
                return Response(status: .forbidden, headers: headers)
            }

            let key = self.generate_authkey(user: user)

            self.VDebug("Authenticated \(user.info()) until \(key.expiration_date())")
            let response = Structs.U.AUTH.POST.Res(authkey: key.key.uuidString, expires: key.expiration_datetime())
            return try Response(status: .ok, headers: headers, body: .init(data: self.encoder.encode(response)))
        }

        // Drop an existing authkey to invalidate it
        self.app.delete("u", "auth") { req in
            let request: Structs.U.AUTH.DELETE.Req = try req.content.decode(Structs.U.AUTH.DELETE.Req.self)

            // Search for the key
            guard let key = self.authkeys.removeValue(forKey: request.authkey) else {
                self.VDebug("Key \(request.authkey) hasn't been found")
                return Response(status: .ok)
            }

            self.VDebug("Invalidated authkey for \(key.user.info())")

            return Response(status: .ok)
        }

        // Refresh an expiring authkey for a new one
        self.app.patch("u", "auth") { req in
            let request: Structs.U.AUTH.PATCH.Req = try req.content.decode(Structs.U.AUTH.PATCH.Req.self)

            var headers = HTTPHeaders()
            headers.add(name: .contentType, value: "application/json")

            // Search for the key
            guard let old_key = self.authkeys.removeValue(forKey: request.authkey) else {
                self.VDebug("Key \(request.authkey) hasn't been found")
                return Response(status: .forbidden)
            }

            // Check if the key is still valid
            if (old_key.is_expired()) {
                self.VDebug("Key \(old_key) has expired")
                return Response(status: .forbidden)
            }

            let key = self.generate_authkey(user: old_key.user)

            self.VDebug("Refreshed key for \(key.user.info()), valid until: \(key.expiration_date()), \(self.authkeys.count) active keys")
            let response = Structs.U.AUTH.PATCH.Res(authkey: key.key.uuidString, expires: key.expiration_datetime())
            return try Response(status: .ok, headers: headers, body: .init(data: self.encoder.encode(response)))
        }

        //
        // MARK: User management /u/user
        //

        self.app.put("u", "user") { req in
            let request: Structs.U.USER.PUT.Req = try req.content.decode(Structs.U.USER.PUT.Req.self)

            guard let key = self.get_authkey(authkey: request.authkey) else {
                return Response(status: .unauthorized)
            }

            let user = key.user

            // The user has to either be a member of group 0 (root) or "usermanager"
            if (try !user.is_member_of(gid: 0) && !user.is_member_of(groupname: "usermanager")) {
                self.VDebug("\(user.info()) has no permission to create users")
                return Response(status: .forbidden)
            }

            switch try self.db.user_create(username: request.username, password: request.password) {
            case .failure(_):
                return Response(status: .conflict)
            case .success(let new_user):
                // Create a group for that user
                let group = try self.db.group_create(groupname: request.username).get()
                try new_user.join_group(group: group)

                for group in request.groups {
                    try new_user.join_group(gid: group)
                }

                var headers = HTTPHeaders()
                headers.add(name: .contentType, value: "application/json")

                self.VDebug("Created new \(new_user.info())")

                let response = Structs.U.USER.PUT.Res(uid: new_user.uid, username: new_user.username, groups: try new_user.get_group_ids())
                return try Response(status: .ok, headers: headers, body: .init(data: self.encoder.encode(response)))
            }
        }

        self.app.delete("u", "user") { req in
            let request: Structs.U.USER.DELETE.Req = try req.content.decode(Structs.U.USER.DELETE.Req.self)

            guard let key = self.get_authkey(authkey: request.authkey) else {
                return Response(status: .unauthorized)
            }

            let user = key.user

            // The user has to either be a member of group 0 (root) or "usermanager"
            if (try !user.is_member_of(gid: 0) && !user.is_member_of(groupname: "usermanager")) {
                self.VDebug("\(user.info()) has no permission to remove users")
                return Response(status: .forbidden)
            }

            guard let del_user = try self.db.user_select(uid: request.uid) else {
                return Response(status: .notFound)
            }

            self.VDebug("Removing \(del_user.info())")

            if let del_group = try self.db.group_select(groupname: del_user.username) {
                try del_group.delete()
            }

            try del_user.delete()

            for key in self.authkeys {
                if key.value.user.uid == del_user.uid {
                    self.authkeys.removeValue(forKey: key.key)
                }
            }

            return Response(status: .ok)
        }

        app.get("u", "user", "groups") { req in
            let request: Structs.U.USER.GROUPS.GET.Req = try req.content.decode(Structs.U.USER.GROUPS.GET.Req.self)

            guard let key = self.get_authkey(authkey: request.authkey) else {
                return Response(status: .unauthorized)
            }

            let user = key.user

            var headers = HTTPHeaders()
            headers.add(name: .contentType, value: "application/json")

            var processed_user = user
            // If there is a specific uid requested
            if let uid = request.uid {
                // Check if the requested uid is notthe user's uid
                if uid != user.uid {
                    // Check for permission
                    if (try !user.is_member_of(gid: 0) && !user.is_member_of(groupname: "usermanager")) {
                        self.VDebug("\(user.info()) has no permission to retrieve other user's group information")
                        return Response(status: .forbidden)
                    }

                    processed_user = try self.db.user_select(uid: uid)!
                }
            }

            var groups: [Structs.U.USER.GROUPS.GET.Res.RGroup] = []
            for group in try processed_user.get_groups() {
                groups.append(Structs.U.USER.GROUPS.GET.Res.RGroup(gid: group.gid, groupname: group.groupname))
            }

            let response = Structs.U.USER.GROUPS.GET.Res(uid: processed_user.uid, groups: groups)
            return try Response(status: .ok, headers: headers, body: .init(data: self.encoder.encode(response)))
        }

        //
        // MARK: Group management /u/group
        //

        self.app.put("u", "group") { req in
            let request: Structs.U.GROUP.PUT.Req = try req.content.decode(Structs.U.GROUP.PUT.Req.self)

            guard let key = self.get_authkey(authkey: request.authkey) else {
                return Response(status: .unauthorized)
            }

            let user = key.user

            // The user has to either be a member of group 0 (root) or "usermanager"
            if (try !user.is_member_of(gid: 0) && !user.is_member_of(groupname: "usermanager")) {
                self.VDebug("\(user.info()) has no permission to create users")
                return Response(status: .forbidden)
            }

            switch try self.db.group_create(groupname: request.groupname) {
            case .failure(_):
                return Response(status: .conflict)
            case .success(let new_group):
                var headers = HTTPHeaders()
                headers.add(name: .contentType, value: "application/json")

                self.VDebug("Created new \(new_group.info())")

                let response = Structs.U.GROUP.PUT.Res(gid: new_group.gid, groupname: new_group.groupname)
                return try Response(status: .ok, headers: headers, body: .init(data: self.encoder.encode(response)))
            }
        }

        self.app.delete("u", "group") { req in
            let request: Structs.U.GROUP.DELETE.Req = try req.content.decode(Structs.U.GROUP.DELETE.Req.self)

            guard let key = self.get_authkey(authkey: request.authkey) else {
                return Response(status: .unauthorized)
            }

            let user = key.user

            // The user has to either be a member of group 0 (root) or "usermanager"
            if (try !user.is_member_of(gid: 0) && !user.is_member_of(groupname: "usermanager")) {
                self.VDebug("\(user.info()) has no permission to remove users")
                return Response(status: .forbidden)
            }

            guard let del_group = try self.db.group_select(gid: request.gid) else {
                return Response(status: .notFound)
            }

            self.VDebug("Removing \(del_group.info())")

            try del_group.delete()

            return Response(status: .ok)
        }

        //
        // MARK: Group membership /u/group/assign
        //

        self.app.put("u", "group", "assign") { req in
            let request: Structs.U.GROUP.ASSIGN.PUT.Req = try req.content.decode(Structs.U.GROUP.ASSIGN.PUT.Req.self)

            guard let key = self.get_authkey(authkey: request.authkey) else {
                return Response(status: .unauthorized)
            }

            let req_user = key.user

            // The user has to either be a member of group 0 (root) or "usermanager"
            if (try !req_user.is_member_of(gid: 0) && !req_user.is_member_of(groupname: "usermanager")) {
                self.VDebug("\(req_user.info()) has no permission to assign to groups")
                return Response(status: .forbidden)
            }

            // Get the user to assign
            guard let user = try self.db.user_select(uid: request.uid) else {
                return Response(status: .notFound)
            }

            for gid in request.groups {
                // Only users in group 0 (root) can assign to that group
                if try gid == 0 && !req_user.is_member_of(gid: 0) {
                    self.VDebug("\(req_user.info()) tried to assign to 'root' {0}")
                    return Response(status: .notAcceptable)
                }

                self.VDebug("Assigning \(user.info()) to gid {\(gid)}")
                try user.join_group(gid: gid)
            }

            var headers = HTTPHeaders()
            headers.add(name: .contentType, value: "application/json")

            let response = Structs.U.GROUP.ASSIGN.PUT.Res(uid: user.uid, groups: try user.get_group_ids())
            return try Response(status: .ok, headers: headers, body: .init(data: self.encoder.encode(response)))
        }

        self.app.delete("u", "group", "assign") { req in
            let request: Structs.U.GROUP.ASSIGN.DELETE.Req = try req.content.decode(Structs.U.GROUP.ASSIGN.DELETE.Req.self)

            guard let key = self.get_authkey(authkey: request.authkey) else {
                return Response(status: .unauthorized)
            }

            let req_user = key.user

            // The user has to either be a member of group 0 (root) or "usermanager"
            if (try !req_user.is_member_of(gid: 0) && !req_user.is_member_of(groupname: "usermanager")) {
                self.VDebug("\(req_user.info()) has no permission to remove from groups")
                return Response(status: .forbidden)
            }

            // Get the user to assign
            guard let user = try self.db.user_select(uid: request.uid) else {
                return Response(status: .notFound)
            }

            for gid in request.groups {
                // Only users in group 0 (root) can remove from that group
                if try gid == 0 && !req_user.is_member_of(gid: 0) {
                    self.VDebug("\(req_user.info()) tried to remove from 'root' {0}")
                    return Response(status: .notAcceptable)
                }

                self.VDebug("Removing \(user.info()) from gid {\(gid)}")
                try user.leave_group(gid: gid)
            }

            var headers = HTTPHeaders()
            headers.add(name: .contentType, value: "application/json")

            let response = Structs.U.GROUP.ASSIGN.DELETE.Res(uid: user.uid, groups: try user.get_group_ids())
            return try Response(status: .ok, headers: headers, body: .init(data: self.encoder.encode(response)))
        }
    }
}

extension VAPI.Structs {
    /// `/u`
    struct U {
        /// `/u/auth`
        struct AUTH {
            /// `/u/auth` - POST
            struct POST {
                struct Req : Codable {
                    let username: String
                    let password: String
                }
                struct Res : Codable {
                    let authkey: String
                    let expires: UInt64
                }
            }
            /// `/u/auth` - DELETE
            struct DELETE {
                struct Req : Codable {
                    let authkey: String
                }
            }
            /// `/u/auth` - PATCH
            struct PATCH {
                struct Req : Codable {
                    let authkey: String
                }
                struct Res : Codable {
                    let authkey: String
                    let expires: UInt64
                }
            }
        }

        /// `/u/user`
        struct USER {
            /// `/u/user` - PUT
            struct PUT {
                struct Req : Codable {
                    let authkey: String
                    let username: String
                    let password: String
                    let groups: [Int64]
                }
                struct Res : Codable {
                    let uid: Int64
                    let username: String
                    let groups: [Int64]
                }
            }
            /// `/u/user` - DELETE
            struct DELETE {
                struct Req : Codable {
                    let authkey: String
                    let uid: Int64
                }
            }

            /// `/u/user/groups`
            struct GROUPS {
                /// `/u/user/groups` - GET
                struct GET {
                    struct Req : Codable {
                        let authkey: String
                        let uid: Int64?
                    }
                    struct Res : Codable {
                        struct RGroup : Codable {
                            let gid: Int64
                            let groupname: String
                        }

                        let uid: Int64
                        let groups: [RGroup]
                    }
                }
            }
        }

        /// `/u/group`
        struct GROUP {
            /// `/u/group` - PUT
            struct PUT {
                struct Req : Codable {
                    let authkey: String
                    let groupname: String
                }
                struct Res : Codable {
                    let gid: Int64
                    let groupname: String
                }
            }
            /// `/u/group` - DELETE
            struct DELETE {
                struct Req : Codable {
                    let authkey: String
                    let gid: Int64
                }
            }
            /// `/u/group/assign`
            struct ASSIGN {
                /// `/u/group/assign` - PUT
                struct PUT {
                    struct Req : Codable {
                        let authkey: String
                        let uid: Int64
                        let groups: [Int64]
                    }
                    struct Res : Codable {
                        let uid: Int64
                        let groups: [Int64]
                    }
                }
                /// `/u/group/assign` - DELETE
                struct DELETE {
                    struct Req : Codable {
                        let authkey: String
                        let uid: Int64
                        let groups: [Int64]
                    }
                    struct Res : Codable {
                        let uid: Int64
                        let groups: [Int64]
                    }
                }
            }
        }
    }
}
