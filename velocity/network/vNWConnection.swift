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

/// A common protocol for all network connections Velocity can handle
protocol VNWConnection {
    /// Starts up the connection and allows it to transition into the `ready` state
    func start()

    /// Send the supplied data to the connection
    /// - Parameter data: The data to send
    func send(_ data: Data) throws

    /// Receives a maximum of `self.buf_len` bytes from the connection
    /// > Warning: This will block the current `DispatchQueue`
    /// - Returns: A `Data` object containing the received bytes
    func receive() throws -> Data

    /// Provides a description for the connection
    func describe() -> String

    /// Cancels the connection (closes it)
    func cancel()

    /// This function gets called once the connection is ready for communicating
    func ready_callback(_ cb: @escaping () -> Bool)
}

extension VNWConnection {
    /// Sends the supplied data array to the connection
    /// - Parameter data: The data in a `UInt8` array
    func send_arr(_ data: [UInt8]) throws {
        try self.send(Data(bytes: data, count: data.count));
    }

    /// Receives a maximum of `self.buf_len` bytes from the connection
    /// > Warning: This will block the current `DispatchQueue`
    /// - Returns: An array of `UInt8` received from the connection
    func receive_arr() throws -> [UInt8] {
        return Array<UInt8>(try self.receive());
    }
}

/// An enum of all the possible connection errors that can occur
enum VConnectionError : Error {
    /// The connection closed while waiting for a message
    case ConnectionClosed
    /// Some other error occured
    case Other(String)
}
