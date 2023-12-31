//
//  vNWConnection.swift
//  velocity
//
//  Created by Max Kofler on 12/06/23.
//

import Foundation
import Network

/// Represents a NWConnection object using 2 dispatch queues
///
/// After this new object has been created, use the `start()` method to activate the connection for traffic.
///
/// Once the connection has been established, the `on_ready()` function gets called and if `cb_on_ready` isn't `nil`, it will get called, too
class VNWConnection {
    /// The connection this VNWConnection builds on
    internal let connection: NWConnection;
    /// The queue to perform all the networking operations on
    internal let io_queue: DispatchQueue;
    /// The queue to dispatch callbacks on
    let user_queue: DispatchQueue;
    /// The maximum amount of bytes that can be received at once
    var buf_len = UINT16_MAX;
    /// The callback for when the connection is ready to transfer user data
    /// - Returns: `true` if the connection should persist, else `false`
    var cb_on_ready: (() -> Bool)? = nil;

    /// Initializes a new `VNWConnection` object from a `NWConnection` object
    ///
    /// This new object uses 2 `DispatchQueues` for managing its io.
    ///
    /// The `io_queue` should always be left free for network traffic to come through. If a blocking operation on this queue gets executed, all the network traffic halts.
    ///
    /// The `user_queue` gets used for calling back from this object. This queue can be shared more easily.
    ///
    /// > Warning: Remember to call `start()` to perform the necessary handshakes
    /// - Parameter connection: The connection to use
    /// - Parameter io_queue: (optional) The `DispatchQueue` to use for Networking IO on the socket, if `nil`, a new queue gets created.
    /// - Parameter user_queue: (optional) The `DispatchQueue` to use for all the callbacks and function calls, if `nil`, a new queue gets created.
    init(connection: NWConnection, io_queue: DispatchQueue? = nil, user_queue: DispatchQueue? = nil) {
        self.connection = connection;

        if let io_queue = io_queue {
            self.io_queue = io_queue;
        } else {
            self.io_queue = DispatchQueue(label: "io.\(self.connection.describe())");
        }

        if let user_queue = user_queue {
            self.user_queue = user_queue;
        } else {
            self.user_queue = DispatchQueue(label: "user.\(self.connection.describe())");
        }

        self.connection.stateUpdateHandler = self.state_update;
    }

    /// Starts up this connection and allows it to transition into the `ready` state.
    func start() {
        self.user_queue.sync {
            self.connection.start(queue: self.io_queue);
        }
    }

    /// This function gets called once the connection is ready for communicating.
    ///
    /// This function gets invoked on the `user_queue`
    func on_ready() {
        if let cb = self.cb_on_ready {
            if !cb() {
                self.connection.cancel();
            }
        }
    }

    /// Send the supplied data to the connection
    /// - Parameter data: The data to send
    func send(_ data: Data) throws {
        let semaphore = DispatchSemaphore(value: 0);
        var error: VConnectionError? = nil;
        self.connection.send(content: data, completion: .contentProcessed() { err in
            if let e = err {
                error = VConnectionError.Other("When sending: \(e)");
            }
            semaphore.signal();
        });

        semaphore.wait();

        if let error = error {
            throw error;
        }
    }

    /// Sends the supplied data array to the connection
    /// - Parameter data: The data in a `UInt8` array
    func send_arr(_ data: [UInt8]) throws {
        try self.send(Data(bytes: data, count: data.count));
    }

    /// Receives a maximum of `self.buf_len` bytes from the connection.
    /// > Warning: This will block the current `DispatchQueue`, make sure this does not get called from the connection's
    /// > `io_queue`, due to it getting blocked and thus leading to a deadlock!
    /// - Returns: A `Data` object containing the received bytes
    func receive() throws -> Data {
        enum Res {
            case Ok(Data)
            case Err(VConnectionError)
        };

        let semaphore = DispatchSemaphore(value: 0);
        var received: Res = .Err(VConnectionError.Other("Unknown"));

        connection.receive(minimumIncompleteLength: 0, maximumLength: Int(self.buf_len)) { (data, _, _, error) in
            // If we have an error, throw it
            if let error = error {
                received = .Err(VConnectionError.Other("When receiving: \(error)"))
            } else {
                // If there is data, return it, else the connection closed on us
                if let data = data {
                    received = .Ok(data)
                } else {
                    received = .Err(.ConnectionClosed)
                }
            }

            semaphore.signal();
        }

        semaphore.wait();

        switch received {
        case .Ok(let data):
            return data;
        case .Err(let err):
            throw err;
        };
    }

    /// Receives a maximum of `self.buf_len` bytes from the connection.
    /// > Warning: This will block the current `DispatchQueue`, make sure this does not get called from the connection's
    /// > `io_queue`, due to it getting blocked and thus leading to a deadlock!
    /// - Returns: An array of `UInt8` received from the connection
    func receive_arr() throws -> [UInt8] {
        return Array<UInt8>(try self.receive());
    }

    /// Provides a description of the connection: `"<host>(<port>)"` or `"NONE"`
    func describe() -> String {
        return self.connection.describe();
    }

    /// An internal function to handle any status updates of the connection
    internal func state_update(state: NWConnection.State) {
        self.user_queue.async {
            switch state {
            case .ready:
                self.on_ready();
            case _:
                break;
            }
        }
    }
}

/// An enum of all the possible connection errors that can occur
enum VConnectionError : Error {
    /// The connection closed while waiting for a message
    case ConnectionClosed
    /// Some other error occured
    case Other(String)
}

extension NWConnection {
    /// Provides a description of the connection: `"<host>(<port>)"` or `"NONE"`
    func describe() -> String {
        switch self.endpoint {
        case .hostPort(let host, let port):
            return "\(host)(\(port))";
        default:
            return "NONE";
        }
    }
}
