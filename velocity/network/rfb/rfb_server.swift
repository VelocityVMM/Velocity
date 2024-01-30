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
import Network

/// Represents a server that is able to respond to `RFB` connections
class VRFBServer : Loggable {
    let context: String

    /// The port to listen on
    let port: UInt16
    /// The listener struct to listen for incoming network connections
    let listener: NWListener
    /// The virtual machine manager to pass into `VRFBSession`s
    let manager: VMManager

    init(port: UInt16, manager: VMManager) throws {
        self.port = port
        self.listener = try NWListener(using: NWParameters(tls: nil, tcp: NWProtocolTCP.Options()), on: NWEndpoint.Port(rawValue: port)!)
        self.context = "[RFB(\(port))]"
        self.manager = manager
    }

    deinit {
        self.listener.cancel()
    }

    /// Starts this server by dispatching it to a new DispatchQueue
    func start() {
        let queue = DispatchQueue(label: "eu.zimsneexh.Velocity.RFBServer.\(self.port)")

        listener.newConnectionHandler = { new_connection in
            self.addNewConnection(connection: new_connection)
        }

        listener.start(queue: queue)
    }

    /// Adds a new connection by performing a handshake
    /// - Parameter socket: The socket that the client listens on
    internal func addNewConnection(connection: NWConnection) {
        do {
            VInfo("Incoming connection: \(connection.describe())")
            let new_con = VNWConnection(connection: connection)

            // Create the new session by attaching it to the appropriate virtual machine
            // We can dispose this reference to that object due to it attaching itself to the provided vm
            let _ = try VRFBSession(self, vm_manager: self.manager, connection: new_con)
        } catch let error {
            VErr("Failed to establish a session with \(connection.describe()): \(error)")
            return
        }
    }
}
