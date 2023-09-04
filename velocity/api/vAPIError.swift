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
    /// An enumeration of all possible error codes that can be thrown by the Velocity API
    enum ErrorCode : Int64, Encodable {

        /// An unauthorized request has been made
        case UNAUTHORIZED = 100

        /// `/u/auth - POST`: Authentication failed (username or password do not match)
        case U_AUTH_POST_AUTH_FAILED = 1100
        /// `/u/auth - PUT`: The old authkey hasn't been found
        case U_AUTH_PATCH_KEY_NOT_FOUND = 1400
        /// `/u/auth - PUT`: The old authkey has expired
        case U_AUTH_PATCH_KEY_EXPIRED = 1401

        // MARK: /u/user: 2xxx

        /// `/u/user - POST`: The `velocity.user.view` permission is missing
        case U_USER_POST_PERMISSION = 2100
        /// `/u/user - POST`: The requested user hasn't been found
        case U_USER_POST_NOT_FOUND = 2110

        /// `/u/user - PUT`: The `velocity.user.create` permission is missing
        case U_USER_PUT_PERMISSION = 2200
        /// `/u/user - PUT`: There is already a user with the same name
        case U_USER_PUT_CONFLICT = 2220

        /// `/u/user - DELETE`: The `velocity.user.remove` permission is missing
        case U_USER_DELETE_PERMISSION = 2300
        /// `/u/user - DELETE`: The user hasn't been found
        case U_USER_DELETE_NOT_FOUND = 2310

        // MARK: /u/user/list: 3xxx

        /// `/u/user/list - POST`: The `velocity.user.list` permission is missing
        case U_USER_LIST_POST_PERMISSION = 3100

        // MARK: /u/user/permission: 4xxx

        /// `/u/user/permission - PUT`: The `velocity.user.assign` permission is missing
        case U_USER_PERMISSION_PUT_PERMISSION = 4200
        /// `/u/user/permission - PUT`: The assigned user hasn't been found
        case U_USER_PERMISSION_PUT_USER_NOT_FOUND = 4210
        /// `/u/user/permission - PUT`: The assigned group hasn' been found
        case U_USER_PERMISSION_PUT_GROUP_NOT_FOUND = 4211
        /// `/u/user/permission - PUT`: The to assign permission hasn't been found
        case U_USER_PERMISSION_PUT_PERMISSION_NOT_FOUND = 4212
        /// `/u/user/permission - PUT`: The permission assigned is too high
        case U_USER_PERMISSION_PUT_HIGHER_PERMISSION = 4220

        /// `/u/user/permission - DELETE`: The `velocity.user.revoke` permission is missing
        case U_USER_PERMISSION_DELETE_PERMISSION = 4300
        /// `/u/user/permission - DELETE`: The revoked user hasn't been found
        case U_USER_PERMISSION_DELETE_USER_NOT_FOUND = 4310
        /// `/u/user/permission - DELETE`: The revoked group hasn't been found
        case U_USER_PERMISSION_DELETE_GROUP_NOT_FOUND = 4311
        /// `/u/user/permission - DELETE`: The to revoke permission hasn't been found
        case U_USER_PERMISSION_DELETE_PERMISSION_NOT_FOUND = 4312

        // MARK: /u/group: 5xxx

        /// `/u/group - POST`: The `velocity.group.view` permission is missing
        case U_GROUP_POST_PERMISSION = 5100
        /// `/u/group - POST`: The group hasn't been found
        case U_GROUP_POST_NOT_FOUND = 5110

        /// `/u/group - PUT`:The `velocity.group.create` permission is missing
        case U_GROUP_PUT_PERMISSION = 5200
        /// `/u/group - PUT`: The parent group hasn't been found
        case U_GROUP_PUT_PARENT_NOT_FUND = 5210
        /// `/u/group - PUT`: There does already exist a group with the same name within the parent group
        case U_GROUP_PUT_CONFLICT = 5220

        /// `/u/group - DELETE`: The `velocity.group.remove` permission is missing
        case U_GROUP_DELETE_PERMISSION = 5300
        /// `/u/group - DELETE`: The group to delete hasn't been found
        case U_GROUP_DELETE_NOT_FOUND = 5310

        // MARK: /u/group/list: 6xxx

        /// `/u/group/list - POST`: The `velocity.group.list` permission is missing
        case U_GROUP_LIST_POST_PERMISSION = 6100
    }
}

extension VAPI.ErrorCode {
    /// Returns the matching `HTTP` status code for an error code
    func get_http_status() -> HTTPStatus {
        switch self {

        case .UNAUTHORIZED: return .unauthorized

        // /u/auth
        case .U_AUTH_POST_AUTH_FAILED: return .forbidden
        case .U_AUTH_PATCH_KEY_NOT_FOUND: return .forbidden
        case .U_AUTH_PATCH_KEY_EXPIRED: return .forbidden


        // /u/user - POST
        case .U_USER_POST_PERMISSION: return .forbidden
        case .U_USER_POST_NOT_FOUND: return .notFound

        // /u/user - PUT
        case .U_USER_PUT_PERMISSION: return .forbidden
        case .U_USER_PUT_CONFLICT: return .conflict

        // /u/user - DELETE
        case .U_USER_DELETE_PERMISSION: return .forbidden
        case .U_USER_DELETE_NOT_FOUND: return .notFound

        // /u/user/list - POST
        case .U_USER_LIST_POST_PERMISSION: return .forbidden

        // /u/user/permission - PUT
        case .U_USER_PERMISSION_PUT_PERMISSION: return .forbidden
        case .U_USER_PERMISSION_PUT_USER_NOT_FOUND: return .notFound
        case .U_USER_PERMISSION_PUT_GROUP_NOT_FOUND: return .notFound
        case .U_USER_PERMISSION_PUT_PERMISSION_NOT_FOUND: return .notFound
        case .U_USER_PERMISSION_PUT_HIGHER_PERMISSION: return .forbidden

        // /u/user/permission - DELETE
        case .U_USER_PERMISSION_DELETE_PERMISSION: return .forbidden
        case .U_USER_PERMISSION_DELETE_USER_NOT_FOUND: return .notFound
        case .U_USER_PERMISSION_DELETE_GROUP_NOT_FOUND: return .notFound
        case .U_USER_PERMISSION_DELETE_PERMISSION_NOT_FOUND: return .notFound

        // /u/group - POST
        case .U_GROUP_POST_PERMISSION: return .forbidden
        case .U_GROUP_POST_NOT_FOUND: return .notFound

        // /u/group - PUT
        case .U_GROUP_PUT_PERMISSION: return .forbidden
        case .U_GROUP_PUT_PARENT_NOT_FUND: return .notFound
        case .U_GROUP_PUT_CONFLICT: return .conflict

        // /u/group - DELETE
        case .U_GROUP_DELETE_PERMISSION: return .forbidden
        case .U_GROUP_DELETE_NOT_FOUND: return .notFound

        // /u/group/list - POST
        case .U_GROUP_LIST_POST_PERMISSION: return .forbidden

        }
    }

    /// Returns the matching error message for an error code
    func get_message() -> String {
        switch self {

        case .UNAUTHORIZED: return "Unauthorized: Authkey is invalid or not present"

        // /u/auth
        case .U_AUTH_POST_AUTH_FAILED: return "Authentication failed"
        case .U_AUTH_PATCH_KEY_NOT_FOUND: return "Authkey does not exist"
        case .U_AUTH_PATCH_KEY_EXPIRED: return "Authkey has expired"

        // /u/user - POST
        case .U_USER_POST_PERMISSION: return "Permission 'velocity.user.view' is needed"
        case .U_USER_POST_NOT_FOUND: return "User has not been found"

        // /u/user - PUT
        case .U_USER_PUT_PERMISSION: return "Permission 'velocity.user.create' is needed"
        case .U_USER_PUT_CONFLICT: return "A user with the same name exists"

        // /u/user - DELETE
        case .U_USER_DELETE_PERMISSION: return "Permission 'velocity.user.remove' is needed"
        case .U_USER_DELETE_NOT_FOUND: return "User has not been found"

        // /u/user/list - POST
        case .U_USER_LIST_POST_PERMISSION: return "Permission 'velocity.user.list' is needed"

        // /u/user/permission - PUT
        case .U_USER_PERMISSION_PUT_PERMISSION: return "Permission 'velocity.user.assign' is needed"
        case .U_USER_PERMISSION_PUT_USER_NOT_FOUND: return "User has not been found"
        case .U_USER_PERMISSION_PUT_GROUP_NOT_FOUND: return "Group has not been found"
        case .U_USER_PERMISSION_PUT_PERMISSION_NOT_FOUND: return "Permission has not been found"
        case .U_USER_PERMISSION_PUT_HIGHER_PERMISSION: return "Assigned permission is too high"

        // /u/user/permission - DELETE
        case .U_USER_PERMISSION_DELETE_PERMISSION: return "Permission 'velocity.user.revoke' is needed"
        case .U_USER_PERMISSION_DELETE_USER_NOT_FOUND: return "User has not been found"
        case .U_USER_PERMISSION_DELETE_GROUP_NOT_FOUND: return "Group has not been found"
        case .U_USER_PERMISSION_DELETE_PERMISSION_NOT_FOUND: return "Permission has not been found"

        // /u/group - POST
        case .U_GROUP_POST_PERMISSION: return "Permission 'velocity.group.view' is needed"
        case .U_GROUP_POST_NOT_FOUND: return "Group has not been found"

        // /u/group - PUT
        case .U_GROUP_PUT_PERMISSION: return "Permission 'velocity.group.create' is needed"
        case .U_GROUP_PUT_PARENT_NOT_FUND: return "Parent group has not been found"
        case .U_GROUP_PUT_CONFLICT: return "A group with the same name exists within the parent group"

        // /u/group - DELETE
        case .U_GROUP_DELETE_PERMISSION: return "Permission 'velocity.group.remove' is needed"
        case .U_GROUP_DELETE_NOT_FOUND: return "Group has not been found"

        // /u/group/list - POST
        case .U_GROUP_LIST_POST_PERMISSION: return "Permission 'velocity.group.list' is needed"

        }
    }
}

extension VAPI {
    /// An error thrown by the Velocity API
    struct Error : Encodable {
        /// The error code
        let code: ErrorCode
        /// A matching message
        let message: String
    }

    /// Construct a new error from an error code
    /// - Parameter code: The error code to return
    func error(code: ErrorCode) throws -> Response {
        let error = Error(code: code, message: code.get_message())

        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "application/json")

        return try Response(status: code.get_http_status(), headers: headers, body: .init(data: self.encoder.encode(error)))
    }

    /// Construct a new error from an error code and an additional string
    /// - Parameter code: The error code to return
    /// - Parameter additional: The additional message
    func error(code: ErrorCode, _ additional: String) throws -> Response {
        let error = Error(code: code, message: "\(code.get_message()): \(additional)")

        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "application/json")

        return try Response(status: code.get_http_status(), headers: headers, body: .init(data: self.encoder.encode(error)))
    }
}
