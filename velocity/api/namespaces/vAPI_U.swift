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

            self.VDebug("Authenticated \(user.info()) until \(key.expiration_date().description(with: .current))")
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

            self.VDebug("Refreshed key for \(key.user.info()), valid until: \(key.expiration_date().description(with: .current)), \(self.authkeys.count) active keys")
            let response = Structs.U.AUTH.PATCH.Res(authkey: key.key.uuidString, expires: key.expiration_datetime())
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
    }
}
