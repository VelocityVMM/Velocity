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
import CoreGraphics

/// An error that occured during the RFB handshake while setting
/// up a session
internal struct VRFBHandshakeError: Error, LocalizedError {
    let errorDescription: String?

    init(_ description: String) {
        errorDescription = description
    }
}

/// An error during an active RFB session
internal struct VRFBSessionError: Error, LocalizedError {
    let errorDescription: String?

    init(_ description: String) {
        errorDescription = description
    }
}

class VRFBSession : Loggable {
    let context: String

    /// The RFB protocol version string
    static let rfb_version: String = "RFB 003.008"
    /// The security types available (and implemented) for this RFB implementation
    static let available_security_types = [VRFBSecurityType.None]

    /// The underlying connection this session runs on
    let connection: VNWConnection
    /// The name for the session (sent to the client)
    let name: String

    /// The virtual machine associated with this session
    let vm: VirtualMachine
    /// The window of the virtual machine assiciated with this connection
    let vm_window: VirtualMachineWindow

    /// The preferred pixel format for this session
    var pixel_format = VRFBPixelFormat()
    /// The security negotiated security type
    var security: VRFBSecurityType = VRFBSecurityType.None

    /// The framebuffer update request in flight, if there is some
    var cur_fb_update: VRFBFBUpdateRequest? = nil
    /// The dispatch queue to operate on
    let queue: DispatchQueue

    /// Established a new RFB session using the supplied socket by performing the RFB handshake
    /// - Parameter socket: The socket to use for communication
    init(_ server: VRFBServer, vm_manager: VMManager, connection: VNWConnection) throws {
        // TODO: Use authentication to use the correct virtual machine
        guard let vm = vm_manager.vms.first?.value else {
            velocity.VWarn("Dropped RFB connection: No available VM", "[RFBS][\(connection.describe())]")
            connection.connection.cancel()
            throw VRFBSessionError("No available virtual machine")
        }

        guard let vm_window = vm.window else {
            velocity.VWarn("Dropped RFB connection: No displays for VM \(vm.vvm.name)", "[RFBS][\(connection.describe())]")
            connection.connection.cancel()
            throw VRFBSessionError("No display for the requested virtual machine '\(vm.vvm.vmid)'")
        }

        if vm.state != .running {
            velocity.VWarn("VM '\(vm.vvm.name)' is not running", "[RFBS][\(connection.describe())]")
            connection.connection.cancel()
            throw VRFBSessionError("Virtual machine '\(vm.vvm.vmid)' is not running")
        }

        self.context = "[RFBS][\(connection.describe())]"
        self.connection = connection
        self.name = "Velocity - \(vm.vvm.name)"
        self.vm = vm
        self.vm_window = vm_window
        self.queue = DispatchQueue(label: "eu.zimsneexh.Velocity.RFBSession.\(connection.describe())", attributes: .concurrent)

        // Register a callback for when the connection is ready
        self.connection.cb_on_ready = {

            self.queue.async {
                do {
                    try self.on_ready(error_message: nil)
                } catch VConnectionError.ConnectionClosed {
                    self.VInfo("Client \(self.connection.describe()) closed connection")
                } catch let error {
                    self.VErr("Error while processing / receiving message: \(error)")
                }

                // Clean up the window's reference to this session
                let description = self.connection.describe()
                self.vm_window.rfb_sessions.removeAll(where: { x in
                    return description == x.connection.describe()
                })
                self.VDebug("Finished teardown of connection")
            }
            return true
        }


        self.connection.start()
    }


    func on_ready(error_message: String? = nil) throws {
        // Always execute the version handshake, even if an error occured
        try self.handshake_version()

        // If we have an error, reject the security handshake and send the
        // error message and return, we're done here
        if let error_message = error_message {
            try self.handshake_security_reject(error: error_message)
            return
        }

        // Negotiate the security
        try self.handshake_security()

        // Perform the client and server handshakes
        try self.handshake_client_init()
        try self.handshake_server_init()

        self.vm_window.rfb_sessions.append(self)
        self.VTrace("Handshake complete - added session to vm window")

        // Enter an infinite loop of awaiting messages and processing them
        while true {

            var message = try self.connection.receive_arr()
            self.VTrace("Received client message \(message)")

            guard message.count > 0 else {
                VInfo("Client connection closed!")
                break
            }

            // We need to sync up all message handling in a queue
            try self.queue.sync {
                while message.count > 0 {
                    try self.handle_message(message: &message)
                }
            }

        }
    }

    /// Takes an incoming message and handles it accordingly
    /// - Parameter message: The message to handle)
    ///
    /// This function will remove the processed bytes from the `message` to
    /// allow for handling of multiple messages in an array. Due to that,
    /// one should call this function in a loop until `message` is empty
    internal func handle_message(message: inout [UInt8]) throws {
        guard let command = VRFBClientCommand(rawValue: message[0]) else {
            VErr("Client sent invalid command \(message[0])")
            throw VRFBSessionError("Client sent invalid command \(message[0])")
        }

        switch command {
        case VRFBClientCommand.SetPixelFormat: handle_set_pixel_format(message: &message)
        case VRFBClientCommand.SetEncodings: handle_set_encodings(message: &message)
        case VRFBClientCommand.FramebufferUpdateRequest: try handle_fb_update(message: &message)
        case VRFBClientCommand.KeyEvent: handle_key_event(message: &message)
        case VRFBClientCommand.PointerEvent: handle_pointer_event(message: &message)
        case _:
            self.VTrace("Clearing queue due to unimplemented command '\(command)'...")
            message.removeAll()
        }

        if message.count > 0 {
            VTrace("[WARN] Message queue still holds \(message.count) bytes...")
        }
    }
}
