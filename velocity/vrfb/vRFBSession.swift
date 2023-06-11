//
//  vRFBSession.swift
//  velocity
//
//  Created by Max Kofler on 04/06/23.
//

import Foundation
import Socket
import CoreGraphics
import Atomics

internal struct VRFBSessionError: Error, LocalizedError {
    let errorDescription: String?

    init(_ description: String) {
        errorDescription = description
    }
}

internal struct VRFBHandshakeError: Error, LocalizedError {
    let errorDescription: String?

    init(_ description: String) {
        errorDescription = description
    }
}

class VRFBSession : Loggable {
    let server: VRFBServer;
    let socket: Socket;
    let name: String;
    let vm: vVirtualMachine;
    var pixel_format: VRFBPixelFormat;
    var security: VRFBSecurityType = VRFBSecurityType.None;
    var cur_fb_update: VRFBFBUpdateRequest? = nil;
    let queue: DispatchQueue;

    /// Established a new RFB session using the supplied socket by performing the RFB handshake
    /// - Parameter socket: The socket to use for communication
    init(_ server: VRFBServer, vm: vVirtualMachine, socket: Socket) throws {
        self.server = server;
        self.socket = socket;
        self.name = "Velocity - \(vm.name)";
        self.vm = vm;
        self.pixel_format = server.preferred_pixelformat;
        self.queue = DispatchQueue(label: "eu.zimsneexh.Velocity.RFBSessionHandler\(self.socket.describe())");

        super.init(context: "[RFBS][\(self.socket.describe())]");

        try handshake();

        let queue = DispatchQueue(label: "eu.zimsneexh.Velocity.RFBSession\(self.socket.describe())");

        queue.async { [self] in
            var shouldKeepRunning = true

            do {
                repeat {
                    var message = try self.socket.read_arr();
                    VTrace("Received client message \(message)");

                    if message.count > 0 {
                        while message.count > 0 {
                            try self.queue.sync {
                                try self.handle_message(message: &message);
                            }
                        }
                    } else {
                        shouldKeepRunning = false
                        break
                    }

                } while shouldKeepRunning

            } catch let error {
                guard let _ = error as? Socket.Error else {
                    print("Unexpected error by connection at \(socket.remoteHostname):\(socket.remotePort)...")
                    return
                }
                VErr("Socket error: \(error)");
            }

            vm.window?.rfb_sessions.removeAll(where: { e in
                return e.socket == self.socket;
            })
            VInfo("Connection closed, \(vm.window!.rfb_sessions.count) active RFB sessions for vm '\(vm.name)' remaining");
            socket.close()
            return;
        }
    }

    /// A callback for the `VWIndow` to notify this session that the frame has updated
    /// - Parameter frame: The new and updated frame
    func frame_changed(frame: CGImage) throws {
        try self.queue.sync {
            try self.update_fb(image: frame);
        }
    }

    /// The handler for a client `PointerEvent` message
    /// - Parameter message: The message data
    internal func handle_pointer_event(message: inout [UInt8]) {
        if message.count < 6 {
            VErr("[PointerEvent] Expected at least 6 bytes, got \(message.count)");
            message.removeFirst(6)
            return;
        }

        guard let pointer_event = VRFBPointerEvent.unpack(data: Array<UInt8>(message[1...5])) else {
            VErr("[PointerEvent] Could not unpack PointerEvent..")
            message.removeFirst(6)
            return;
        }

        self.vm.send_pointer_event(pointerEvent: pointer_event)
        message.removeFirst(6)
    }

    /// The handler for a client `KeyEvent` message
    /// - Parameter message: The message data
    internal func handle_key_event(message: inout [UInt8]) {
        if message.count < 8 {
            VErr("[KeyEvent] Expected at least 8 bytes, got \(message.count)");
            message.removeFirst(8)
            return;
        }

        guard let key_event = VRFBKeyEvent.unpack(data: Array<UInt8>(message[1...7])) else {
            VErr("[KeyEvent] Could not unpack KeyEvent struct");
            message.removeFirst(8)
            return;
        }

        guard let macos_keycode = convertXKeySymToKeyCode(XKeySym: key_event.key_sym) else {
            VErr("[KeyEvent] Got unmapped X11 KeySym: \(key_event.key_sym)");
            message.removeFirst(8)
            return;
        }

        VTrace("[KeyEvent] Generated KeyEvent: \(macos_keycode)")
        self.vm.send_macos_keyevent(macos_key_event: macos_keycode, pressed: key_event.down_flag)
        message.removeFirst(8)
    }

    /// The handler for a client `SetPixelFormat` message
    /// - Parameter message: The message data
    internal func handle_set_pixel_format(message: inout [UInt8]) {
        if message.count < 20 {
            VErr("[SetPixelFormat] Expected at least 20 bytes, got \(message.count)");
            message = [];
            return;
        }
        guard let new_format = VRFBPixelFormat.unpack(data: Array<UInt8>(message[4...19])) else {
            VErr("Pixel format did go out of range!");
            return;
        }
        self.pixel_format = new_format;
        VDebug("Updated pixel format \(self.pixel_format)");
        if self.cur_fb_update != nil {
            fatalError("[WARN] PixelFormat changed with a frame in flight!");
        }
        message.removeFirst(20);
    }

    /// The handler for a client `SetEncodings` message
    /// - Parameter message: The message data
    internal func handle_set_encodings(message: inout [UInt8]) {
        if message.count < 4 {
            VErr("[SetEncodings] Expected at least 4 bytes, got \(message.count)");
            message = [];
            return;
        }

        let count_encodings = unpack_u16(Array(message[2...3]))!;
        let required_bytes = UInt(4 + count_encodings*4);
        if message.count < required_bytes{
            VErr("[SetEncodings] Encodings message should be \(required_bytes) bytes, got \(message.count)");
            return;
        }

        VInfo("Client advertised \(count_encodings) available encodings");
        message.removeFirst(Int(required_bytes));
    }

    /// The handler for a client `FramebufferUpdateRequest` message
    /// - Parameter message: The message data
    internal func handle_fb_update(message: inout [UInt8]) throws {
        if message.count < 10 {
            VErr("[FBUpdateRequest] Expected at least 10 bytes, got \(message.count)");
            message = [];
            return;
        }
        guard let request = VRFBFBUpdateRequest.unpack(data: Array(message[1...9])) else {
            VErr("Failed to unpack fbupdate struct!");
            return;
        }

        self.cur_fb_update = request;

        if !request.incremental {
            VDebug("Client requested full frame update");
            // If a non-incremental frame is requested, snapshot the screen contents and respond immediately
            let cur_frame = DispatchQueue.main.sync {
                self.vm.window?.capture_window();
            }!;
            try self.update_fb(image: cur_frame);
        }

        VDebug("Received FBUpdateRequest: \(request)");
        message.removeFirst(10);
    }

    /// The handler for client messages
    /// - Parameter message: The message data
    internal func handle_message(message: inout [UInt8]) throws {
        guard let command = VRFBClientCommand(rawValue: message[0]) else {
            VErr("Client sent invalid command \(message[0])");
            throw VRFBSessionError("Client sent invalid command \(message[0])");
        }

        switch command {
        case VRFBClientCommand.SetPixelFormat: handle_set_pixel_format(message: &message);
        case VRFBClientCommand.SetEncodings: handle_set_encodings(message: &message);
        case VRFBClientCommand.FramebufferUpdateRequest: try handle_fb_update(message: &message);
        case VRFBClientCommand.KeyEvent: handle_key_event(message: &message);
        case VRFBClientCommand.PointerEvent: handle_pointer_event(message: &message);
        case _: message.removeFirst(message.count);
        }
    }

    /// Sends out a `FramebufferUpdate` to the client
    /// - Parameter image: The image to send
    internal func update_fb(image: CGImage) throws {
        guard let cur_request = self.cur_fb_update else {
            VTrace("Updated framebuffer but no request in flight");
            return;
        }
        
        let rect = VRFBRect(image: image, request: cur_request);
        let r = rect.pack(px_format: self.pixel_format);

        var data = Array<UInt8>();
        data.append(0); //Message type
        data.append(0); //Padding
        data.append(contentsOf: pack_u16(1));

        data.append(contentsOf: r);

        try self.socket.write_arr(data);
        self.cur_fb_update = nil;
    }

    /// Performs the RFB handshake and negotiates version, security and pixelformats
    internal func handshake() throws {
        // Negotiate protocol version
        try self.version_handshake();

        // Negotiate security
        try self.security_handshake();

        // Await client init
        try self.client_init_handshake();

        // Send the server init
        try self.server_init_handshake();
    }

    /// Perform the version handshake. This negotiates and enforces the server's version
    func version_handshake() throws {
        try self.socket.write_arr(Array<UInt8>("\(self.server.serverVersion)\n".utf8));

        let version_response = try self.socket.read_arr();
        if version_response.count != 12 {
            VErr("Handshake failed: Expected 12 bytes for version, got \(version_response.count)");
            throw VRFBHandshakeError("Handshake failed: Expected 12 bytes for version, got \(version_response.count)");
        }
        VDebug("Protocol version negotiated to \(self.server.serverVersion)");
    }

    /// Perform the security handshake. This uses the server's `security_types`.
    func security_handshake() throws {
        var security_proposal = Array<UInt8>();
        security_proposal.append(UInt8(self.server.security_types.count));
        for sec_type in self.server.security_types {
            security_proposal.append(sec_type.rawValue);
        }

        // Propose the supported security types
        VDebug("Proposing following security types: \(self.server.security_types)");
        try self.socket.write_arr(security_proposal);
        let response = try self.socket.read_arr();
        if response.count != 1 {
            VErr("Security proposal response isn't 1 byte long");
            throw VRFBHandshakeError("Security proposal response isn't 1 byte long");
        }

        // Await the answer from the client
        guard let new_security = VRFBSecurityType(rawValue: response[0]) else {
            VErr("Client responded to security proposal with invalid security type \(response[0])");
            throw VRFBHandshakeError("Client responded to security proposal with invalid security type \(response[0])");
        }

        // Check if the server enabled the responded security type
        if !self.server.security_types.contains(new_security) {
            VErr("Client responded with unsupported security type \(new_security)");

            // Inform the client that this its choice is invalid
            try self.socket.write_arr(pack_u32(VRFBConstants.SECURITY_RESULT_FAILED));

            throw VRFBHandshakeError("Client responded with unsupported security type \(new_security)");
        }
        self.security = new_security;

        // Acknowledge the security handshake
        VDebug("Negotiated security type to '\(self.security)'");
        try self.socket.write_arr(pack_u32(VRFBConstants.SECURITY_RESULT_OK));
    }

    func client_init_handshake() throws {
        let client_init = try self.socket.read_arr();
        if client_init.count != 1 {
            VErr("ClientInit message isn't 1 byte long");
            throw VRFBHandshakeError("ClientInit message isn't 1 byte long");
        }

        VDebug("Client initialized with \(client_init[0])");
    }

    func server_init_handshake() throws {
        var server_init = Array<UInt8>();

        // The screen size
        server_init.append(contentsOf: pack_u16(UInt16(self.vm.screen_size.width)));
        server_init.append(contentsOf: pack_u16(UInt16(self.vm.screen_size.height)));

        // The native pixel format
        server_init.append(contentsOf: self.pixel_format.pack());

        // The name of the server (instance)
        server_init.append(contentsOf: pack_u32(UInt32(self.name.count)));
        server_init.append(contentsOf: self.name.utf8);

        try self.socket.write_arr(server_init);
        VDebug("Sent \(server_init.count) bytes of server init");
    }
}
