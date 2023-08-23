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
    /// Registers all endpoints withing the namespace `/u/auth`
    func register_endpoints_u_auth() throws {
        VDebug("Registering /u/auth endpoints...")

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
