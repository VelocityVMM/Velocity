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

extension VRFBSession {

    /// Perform the version handshake. This negotiates and enforces the server's version
    func handshake_version() throws {
        try self.connection.send_arr(Array<UInt8>("\(Self.rfb_version)\n".utf8))

        let version_response = try self.connection.receive_arr()
        if version_response.count != 12 {
            VErr("Handshake failed: Expected 12 bytes for protocol version, got \(version_response.count)")
            throw VRFBHandshakeError("Handshake failed: Expected 12 bytes for protocol version, got \(version_response.count)")
        }
        VDebug("Protocol version negotiated to '\(Self.rfb_version)'")
    }

    /// Creates a security handshake response that failed with the supplied message
    /// - Parameter error: The error to submit
    func handshake_security_reject(error: String) throws {
        var security_proposal = Array<UInt8>([0x00])
        security_proposal.append(contentsOf: UInt32(error.count).pack())
        security_proposal.append(contentsOf: error.utf8)

        VErr("Refusing RFB connection from '\(self.connection.describe())': '\(error)'")
        try self.connection.send_arr(security_proposal)
    }

    /// Perform the security handshake. This uses the server's `security_types`.
    func handshake_security() throws {
        var security_proposal = Array<UInt8>()
        security_proposal.append(UInt8(Self.available_security_types.count))
        for sec_type in Self.available_security_types {
            security_proposal.append(sec_type.rawValue)
        }

        // Propose the supported security types
        VDebug("Proposing following security types: \(Self.available_security_types)")
        try self.connection.send_arr(security_proposal)
        let response = try self.connection.receive_arr()
        if response.count != 1 {
            VErr("Security proposal response isn't 1 byte long")
            throw VRFBHandshakeError("Security proposal response isn't 1 byte long")
        }

        // Await the answer from the client
        guard let new_security = VRFBSecurityType(rawValue: response[0]) else {
            VErr("Client responded to security proposal with invalid security type \(response[0])")
            throw VRFBHandshakeError("Client responded to security proposal with invalid security type \(response[0])")
        }

        // Check if the server enabled the responded security type
        if !Self.available_security_types.contains(new_security) {
            VErr("Client responded with unsupported security type \(new_security)")

            // Inform the client that this its choice is invalid
            try self.connection.send_arr(VRFBConstants.SECURITY_RESULT_FAILED.pack())

            throw VRFBHandshakeError("Client responded with unsupported security type \(new_security)")
        }
        self.security = new_security

        // Acknowledge the security handshake
        VDebug("Negotiated security type to '\(self.security)'")
        try self.connection.send_arr(VRFBConstants.SECURITY_RESULT_OK.pack())
    }

    /// Perform the `Client Init` handshake part of the RFB connection process
    func handshake_client_init() throws {
        let client_init = try self.connection.receive_arr()
        if client_init.count != 1 {
            VErr("ClientInit message isn't 1 byte long")
            throw VRFBHandshakeError("ClientInit message isn't 1 byte long")
        }

        VDebug("Client initialized with \(client_init[0])")
    }

    /// Perform the `Server Init` handshake part of the RFB connection process
    func handshake_server_init() throws {
        var server_init = Array<UInt8>()

        // The screen size
        let width = UInt16(self.vm_window.screen_size.width)
        let height = UInt16(self.vm_window.screen_size.height)

        server_init.append(contentsOf: UInt16(width).pack())
        server_init.append(contentsOf: UInt16(height).pack())

        // The native pixel format
        server_init.append(contentsOf: self.pixel_format.pack())

        // The name of the server (instance)
        server_init.append(contentsOf: UInt32(self.name.count).pack())
        server_init.append(contentsOf: self.name.utf8)

        try self.connection.send_arr(server_init)
        VDebug("Sent \(server_init.count) bytes of server init")
    }

}
