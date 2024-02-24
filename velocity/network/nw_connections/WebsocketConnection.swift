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
import Vapor

class VWebSocketConnection : VNWConnection, Loggable {
    internal let context: String = "[WS]"

    internal let ws: WebSocket
    internal var cb: (() -> Bool)? = nil

    internal let buf_queue: DispatchQueue
    internal var buf: [UInt8] = []

    internal let buf_lock = NSLock()

    init(ws: WebSocket) {
        self.buf_queue = DispatchQueue(label: "Websocket")
        self.ws = ws

        self.ws.onBinary {ws, data in
            self.buf_queue.sync {
                var data = data
                self.buf = data.readBytes(length: data.readableBytes)!
                self.buf_lock.unlock()
            }
        }
    }

    func start() {
        if let cb = self.cb {
            if !cb() {
                self.cancel()
            }
        }
    }

    func send(_ data: Data) throws {
        if self.ws.isClosed {
            throw VConnectionError.ConnectionClosed
        }

        let arr: [UInt8] = Array(data)
        let s = DispatchSemaphore(value: 0)
        Task {
            try await self.ws.send(arr)
            s.signal()
        }
        s.wait()
    }

    func receive() throws -> Data {
        if self.ws.isClosed {
            throw VConnectionError.ConnectionClosed
        }

        if self.buf.isEmpty {
            self.buf_lock.try()
            self.buf_lock.lock()
        }

        return self.buf_queue.sync {
            let sond = self.buf
            self.buf = []//.removeAll(keepingCapacity: false)
            self.buf_lock.unlock()
            return Data(sond)
        }
    }

    func describe() -> String {
        return "WebSocket"
    }

    func cancel() {
        try! self.ws.close().wait()
    }

    func ready_callback(_ cb: @escaping () -> Bool) {
        self.cb = cb
    }
}
