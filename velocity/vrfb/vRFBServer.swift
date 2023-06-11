//
//  vRFVBServer.swift
//  velocity
//
//  Created by Max Kofler on 04/06/23.
//

import Foundation
import Socket
import Dispatch

extension Socket {
    func describe() -> String {
        return "\(self.remoteHostname)(\(self.remotePort))";
    }
}

/// Represents a server that is able to respond to `RFB` connections
class VRFBServer : Loggable {
    let serverVersion = "RFB 003.008";
    let security_types = [VRFBSecurityType.None];
    let preferred_pixelformat = VRFBPixelFormat();

    let port: Int;
    var listenSocket: Socket? = nil;
    var continueRunningValue = true;
    var connectedSockets = [Int32: Socket]();
    let socketLockQueue = DispatchQueue(label: "eu.zimsneexh.Velocity.socketLockQueue");

    var continueRunning: Bool {
        set(newValue) {
            socketLockQueue.sync {
                self.continueRunningValue = newValue
            }
        }
        get {
            return socketLockQueue.sync {
                self.continueRunningValue
            }
        }
    }

    init(port: Int) {
        self.port = port
        super.init(context: "[RFB(\(port))]");
    }

    deinit {
        self.listenSocket?.close()
    }

    /// Starts this server by dispatching it to a new DispatchQueue
    func start() {
        let queue = DispatchQueue(label: "eu.zimsneexh.Velocity.RFBServer");

        queue.async { [unowned self] in

            do {
                VInfo("Creating socket at port \(self.port)");
                try self.listenSocket = Socket.create(family: .inet)

                guard let socket = self.listenSocket else {
                    VErr("Failed to unwrap new socket");
                    return
                }

                VInfo("Listening on port \(self.port)");
                try socket.listen(on: self.port);

                repeat {
                    let newSocket = try socket.acceptClientConnection();
                    VInfo("Accepted connection from \(newSocket.describe())");
                    self.addNewConnection(socket: newSocket);
                } while self.continueRunning;

            }
            catch let error {
                guard let socketError = error as? Socket.Error else {
                    VErr("Unexpected error!");
                    return;
                }
                if self.continueRunning {
                    VErr("Error reported:\n \(socketError.description)");
                }
            }
        }
    }

    /// Adds a new connection by performing a handshake
    /// - Parameter socket: The socket that the client listens on
    internal func addNewConnection(socket: Socket) {

        // Add the new socket to the list of connected sockets...
        socketLockQueue.sync { [unowned self, socket] in
            self.connectedSockets[socket.socketfd] = socket;
        }

        do {
            guard let vm = Manager.virtual_machines.last else {
                VErr("Could not get last started vm");
                return;
            };

            // Create the new session by attaching it to the appropriate virtual machine
            let session = try VRFBSession(self, vm: vm, socket: socket);
            vm.get_window()?.rfb_sessions.append(session);

            VInfo("Initialized new session with \(socket.describe()), \(vm.get_window()!.rfb_sessions.count) active RFB sessions");
        } catch let error {
            VErr("Failed to establish a session with \(socket.describe()): \(error)");
            return;
        }
    }
}
