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

extension VAPI {
    /// Registers all endpoints withing the namespace `/u`
    func register_endpoints_u() throws {
        // Ensure the root user and group
        let u_root = try self.db.user_ensure(username: "root", password: "root", uid: 0).get()
        let g_root = try self.db.group_ensure(name: "root", parent_gid: 0, gid: 0).get()

        // Ensure permissions
        VDebug("Ensuring permissions...")
        for permission in VAPI.available_permissions {
            let permission = try self.db.permission_ensure(name: permission.name, description: permission.description)
            try u_root.add_permission(group: g_root, permission: permission)
        }

        // Register sub-endpoints
        try self.register_endpoints_u_auth()
    }
}

extension VAPI.Structs {
    struct U {

    }
}
