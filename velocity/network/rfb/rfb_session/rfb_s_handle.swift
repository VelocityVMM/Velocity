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

extension VRFBSession {

    /// The handler for a client `SetPixelFormat` message
    /// - Parameter message: The message data
    internal func handle_set_pixel_format(message: inout [UInt8]) {
        // Check the message length
        if message.count < 20 {
            VErr("[SetPixelFormat] Expected at least 20 bytes, got \(message.count)")
            message.removeAll()
            return
        }

        // Try to unpack the new pixel format
        guard let new_format = VRFBPixelFormat.unpack(data: Array<UInt8>(message[4...19])) else {
            VErr("[SetPixelFormat] Pixel format out of range: \(message[4...19])")
            return
        }

        // Update the pixel format
        self.pixel_format = new_format
        VDebug("[SetPixelFormat] Set pixel format to \(self.pixel_format)")

        // (This should never happen)
        // Check if we don't have any fb updates in flight, this would violate the RFB protocol
        if !self.fb_updates.isEmpty {
            VErr("[SetPixelFormat] PixelFormat changed while FB update in flight (Faulty RFB client implementation)")
        }

        message.removeFirst(20)
    }

    /// The handler for a client `SetEncodings` message
    ///
    /// TODO: This is a dummy, it will simply get the message out of the way
    /// - Parameter message: The message data
    internal func handle_set_encodings(message: inout [UInt8]) {
        // Check the message length
        if message.count < 4 {
            VErr("[SetEncodings] Expected at least 4 bytes, got \(message.count)")
            message = []
            return
        }

        // Unpack the new encodings
        let count_encodings = UInt16.unpack(Array(message[2...3]))!
        let required_bytes = UInt(4 + count_encodings*4)
        if message.count < required_bytes{
            VErr("[SetEncodings] Encodings message should be \(required_bytes) bytes, got \(message.count)")
            return
        }

        // TODO: Unpack the encodings and choose the best one

        VDebug("[SetEncodings] Client advertised \(count_encodings) available encodings")
        message.removeFirst(Int(required_bytes))
    }

    /// The handler for a client `FramebufferUpdateRequest` message
    /// - Parameter message: The message data
    internal func handle_fb_update(message: inout [UInt8]) throws {
        if message.count < 10 {
            VErr("[FBUpdateRequest] Expected at least 10 bytes, got \(message.count)")
            message = []
            return
        }
        guard let request = VRFBFBUpdateRequest.unpack(data: Array(message[1...9])) else {
            VErr("Failed to unpack fbupdate struct!")
            return
        }

        // Push our new framebuffer update
        self.fb_updates.append(request)
        VTrace("Received \(request)")

        if !request.incremental {
            VDebug("Client requested full frame update")
            if let cur_frame = self.vm_window.last_frame {
                try self.update_fb(image: cur_frame)
            }

            // If the client requested the initial framebuffer update,
            // it expects the request to stay valid?
            // So we just push the request after it has been cleared and move on
            // self.cur_fb_update = request
        }

        // Remove the first `10` bytes of the message
        message.removeFirst(10)
    }

    /// Sends out a `FramebufferUpdate` to the client
    /// - Parameter image: The image to send
    internal func update_fb(image: CGImage) throws {
        // Get the oldest update in the queue
        guard let update = self.fb_updates.first else {
            VTrace("Updated framebuffer but no request in flight")
            return
        }

        let rect = VRFBRect(image: image)
        let rect_data = rect.pack(px_format: self.pixel_format)

        var data = Array<UInt8>()

        data.append(0) // Message type
        data.append(0) // Padding

        // TODO: Set the `number-of-rectangles` - currently `1`
        data.append(contentsOf: UInt16(1).pack()) // Number of rectangles

        data.append(contentsOf: rect_data)

        VTrace("Sending \(data.count) bytes of pixel data")
        try self.connection.send_arr(data)
    }

    /// The handler for a client `KeyEvent` message
    /// - Parameter message: The message data
    internal func handle_key_event(message: inout [UInt8]) {
        if message.count < 8 {
            VErr("[KeyEvent] Expected at least 8 bytes, got \(message.count)")
            message.removeFirst(8)
            return
        }

        guard let key_event = VRFBKeyEvent.unpack(data: Array<UInt8>(message[1...7])) else {
            VErr("[KeyEvent] Could not unpack KeyEvent struct")
            message.removeFirst(8)
            return
        }

        guard let macos_key_event = convert_x_keysym_to_key_event(key_event.key_sym) else {
            VErr("[KeyEvent] Got unmapped X11 KeySym: \(key_event.key_sym)")
            message.removeFirst(8)
            return
        }

        VTrace("[KeyEvent] Generated KeyEvent: \(macos_key_event)")
        self.vm_window.send_key_event(event: macos_key_event, pressed: key_event.down_flag)
        //self.vm_window.send_macos_keyevent(macos_key_event: macos_keycode, pressed: key_event.down_flag)
        message.removeFirst(8)
    }

    /// The handler for a client `PointerEvent` message
    /// - Parameter message: The message data
    internal func handle_pointer_event(message: inout [UInt8]) {
        if message.count < 6 {
            VErr("[PointerEvent] Expected at least 6 bytes, got \(message.count)")
            message.removeFirst(6)
            return
        }

        guard let pointer_event = VRFBPointerEvent.unpack(data: Array<UInt8>(message[1...5])) else {
            VErr("[PointerEvent] Could not unpack PointerEvent..")
            message.removeFirst(6)
            return
        }

        self.vm_window.send_pointer_event(event: pointer_event)
        message.removeFirst(6)
    }

}
