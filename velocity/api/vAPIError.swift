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
        /// `/u/auth - POST`: Authentication failed (username or password do not match)
        case U_AUTH_POST_AUTH_FAILED = 100
        /// `/u/auth - PUT`: The old authkey hasn't been found
        case U_AUTH_PATCH_KEY_NOT_FOUND = 101
        /// `/u/auth - PUT`: The old authkey has expired
        case U_AUTH_PATCH_KEY_EXPIRED = 102
    }
}

extension VAPI.ErrorCode {
    /// Returns the matching `HTTP` status code for an error code
    func get_http_status() -> HTTPStatus {
        switch self {

        // /u/auth
        case .U_AUTH_POST_AUTH_FAILED: return .forbidden
        case .U_AUTH_PATCH_KEY_NOT_FOUND: return .forbidden
        case .U_AUTH_PATCH_KEY_EXPIRED: return .forbidden

        }
    }

    /// Returns the matching error message for an error code
    func get_message() -> String {
        switch self {

        // /u/auth
        case .U_AUTH_POST_AUTH_FAILED: return "Authentication failed"
        case .U_AUTH_PATCH_KEY_NOT_FOUND: return "Authkey does not exist"
        case .U_AUTH_PATCH_KEY_EXPIRED: return "Authkey has expired"

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
