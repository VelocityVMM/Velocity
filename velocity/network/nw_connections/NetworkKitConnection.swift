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

/// Represents a NWConnection object using 2 dispatch queues
///
/// After this new object has been created, use the `start()` method to activate the connection for traffic.
///
/// Once the connection has been established, the `on_ready()` function gets called and if `cb_on_ready` isn't `nil`, it will get called, too
class VNetworkKitConnection : VNWConnection {
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

    func cancel() {
        self.connection.cancel()
    }

    func ready_callback(_ cb: @escaping () -> Bool) {
        self.cb_on_ready = cb
    }

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

    func start() {
        self.user_queue.sync {
            self.connection.start(queue: self.io_queue);
        }
    }

    func on_ready() {
        if let cb = self.cb_on_ready {
            if !cb() {
                self.connection.cancel();
            }
        }
    }

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
