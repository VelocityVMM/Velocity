//
//  vAPI_U.swift
//  velocity
//
//  Created by Max Kofler on 31/07/23.
//

import Foundation
import Vapor

extension VAPI {
    func register_endpoints_u() {
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
        }
    }
}
