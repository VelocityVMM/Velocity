//
//  vRFVBServer.swift
//  velocity
//
//  Created by Max Kofler on 04/06/23.
//

import Foundation
import Dispatch
import Network

/// Represents a server that is able to respond to `RFB` connections
class VRFBServer : Loggable {
    let serverVersion = "RFB 003.008";
    let security_types = [VRFBSecurityType.None];
    let preferred_pixelformat = VRFBPixelFormat();

    let listener: NWListener;
    var active_connections = [VNWConnection]();
    let socketLockQueue = DispatchQueue(label: "eu.zimsneexh.Velocity.socketLockQueue");

    init(port: UInt16) throws {
        self.listener = try NWListener(using: NWParameters(tls: nil, tcp: NWProtocolTCP.Options()), on: NWEndpoint.Port(rawValue: port)!);
        super.init(context: "[RFB(\(port))]");
    }

    deinit {
        self.listener.cancel();
    }

    /// Starts this server by dispatching it to a new DispatchQueue
    func start() {
        let queue = DispatchQueue(label: "eu.zimsneexh.Velocity.RFBServer");

        listener.newConnectionHandler = { new_connection in
            self.addNewConnection(connection: new_connection);
        }

        listener.start(queue: queue);
    }

    /// Adds a new connection by performing a handshake
    /// - Parameter socket: The socket that the client listens on
    internal func addNewConnection(connection: NWConnection) {
        do {
            guard let vm = Manager.virtual_machines.last else {
                VErr("Could not get last started vm");
                return;
            };

            let new_con = VNWConnection(connection: connection);

            // Add the new socket to the list of connected sockets...
            socketLockQueue.sync { [unowned self, new_con] in
                self.active_connections.append(new_con);
            }

            // Create the new session by attaching it to the appropriate virtual machine
            // We can dispose this reference to that object due to it attaching itself to the provided vm
            let _ = try VRFBSession(self, vm: vm, connection: new_con);

            VInfo("Initialized new session with \(connection.describe()), \(vm.get_window()!.rfb_sessions.count) active RFB sessions");
        } catch let error {
            VErr("Failed to establish a session with \(connection.describe()): \(error)");
            return;
        }
    }
}
