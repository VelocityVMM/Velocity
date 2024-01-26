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
    /// Registers all endpoints withing the namespace `/u/auth`
    func register_endpoints_u_auth(route: RoutesBuilder) throws {
        VDebug("Registering /u/auth endpoints...")

        //
        // MARK: Authentication /u/auth
        //

        // Authenticate for a new authkey
        route.post() { req in
            let request: Structs.U.AUTH.POST.Req = try req.content.decode(Structs.U.AUTH.POST.Req.self)

            // Get the user
            guard let user = { () -> VDB.User? in
                do {
                    let user = try self.db.user_select(username: request.username)

                    guard let user = user else {
                        self.VDebug("User \(request.username) not found")
                        return nil
                    }

                    if user.pwhash != VDB.hash_pw(request.password) {
                        self.VDebug("Password for user \(request.username) does not match")
                        return nil
                    }

                    return user
                } catch {
                    return nil
                }
            }() else {
                return try self.error(code: .U_AUTH_POST_AUTH_FAILED)
            }

            let key = self.generate_authkey(user: user)

            self.VDebug("Authenticated \(user.info()) until \(key.expiration_date().description(with: .current))")
            return try self.response(Structs.U.AUTH.POST.Res(authkey: key.key.uuidString, expires: key.expiration_datetime()))
        }

        // Drop an existing authkey to invalidate it
        route.delete() { req in
            let request: Structs.U.AUTH.DELETE.Req = try req.content.decode(Structs.U.AUTH.DELETE.Req.self)

            // Search for the key
            guard let key = self.authkeys.removeValue(forKey: request.authkey) else {
                self.VDebug("Key \(request.authkey) hasn't been found")
                return try self.response(nil)
            }

            self.VDebug("Invalidated authkey for \(key.user.info())")

            return try self.response(nil)
        }

        // Refresh an expiring authkey for a new one
        route.patch() { req in
            let request: Structs.U.AUTH.PATCH.Req = try req.content.decode(Structs.U.AUTH.PATCH.Req.self)

            // Search for the key
            guard let old_key = self.authkeys.removeValue(forKey: request.authkey) else {
                self.VDebug("Key \(request.authkey) hasn't been found")
                return try self.error(code: .U_AUTH_PATCH_KEY_NOT_FOUND)
            }

            // Check if the key is still valid
            if (old_key.is_expired()) {
                self.VDebug("Key \(old_key) has expired")
                return try self.error(code: .U_AUTH_PATCH_KEY_EXPIRED)
            }

            let key = self.generate_authkey(user: old_key.user)

            self.VDebug("Refreshed key for \(key.user.info()), valid until: \(key.expiration_date().description(with: .current)), \(self.authkeys.count) active keys")
            return try self.response(Structs.U.AUTH.PATCH.Res(authkey: key.key.uuidString, expires: key.expiration_datetime()))
        }
    }
}

extension VAPI.Structs.U {
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
