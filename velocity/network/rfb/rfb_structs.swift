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
import AppKit

/// The available security types
enum VRFBSecurityType : UInt8 {
    /// No security
    case None = 1
    /// VNC Authentication
    case VNCAuth = 2
    /// RSA-AES Security Type
    case RSA_AES_Sec = 5
    /// RSA-AES Unencrypted Security Type
    case RSA_AES_Unenc = 6
    /// RSA-AES Two-step Security Type
    case RSA_AES_Twostep = 13
    /// Tight Security Type
    case Tight = 16
    /// VeNCrypt
    case VeNCrypt = 19
    /// xvp Authentication
    case XVPAuth = 22
    /// Diffie-Hellman Authentication
    case DiffieHellman = 30
    /// MSLogonII Authentication
    case MSLogonIIAuth = 113
    /// RSA-AES-256 Security Type
    case RSA_AES_256_Sec = 129
    /// RSA-AES-256 Unencrypted Security Type
    case RSA_AES_256_Unenc = 130
    /// RSA-AES-256 Two-step Security Type
    case RSA_AES_256_Twostep = 133
}

/// All possible commands a client can send to the server
enum VRFBClientCommand : UInt8 {
    /// Set the pixel format in which the picture data is sent
    case SetPixelFormat = 0
    /// Set the encodings the client can accept and / or preferres
    case SetEncodings = 2
    /// Request a new framebuffer update if available
    case FramebufferUpdateRequest = 3
    /// A key event
    case KeyEvent = 4
    /// A pointer event
    case PointerEvent = 5
    /// Update the client's cut buffer
    case ClientCutText = 6
}

/// Some contants defined for global use
struct VRFBConstants{
    /// The security result if the security negotiation was successfull
    static let SECURITY_RESULT_OK: UInt32 = 0
    /// The security result if the security negotiation failed
    static let SECURITY_RESULT_FAILED: UInt32 = 1
    /// The security result if the security negotiation failed for too many attempts
    static let SECURITY_RESULT_FAILED_TOO_MANY_ATTEMPTS: UInt32 = 1
}

/// The RFB pixel format struct.
struct VRFBPixelFormat {
    /// How many bits are needed for representing a pixel in the current format
    var bits_per_pixel: UInt8 = 32
    /// The color depth in bits (8 + 8 + 8) = 24
    var depth: UInt8 = 24
    /// If not `0`, this indicates a big endian format
    var big_endian_flag: Bool = false
    /// If not `0`, this indicated a full color pixel format
    var true_color_flag: UInt8 = 1

    /// The maximum value for the `red` channel
    var red_max: UInt16 = 255
    /// The maximum value for the `green` channel
    var green_max: UInt16 = 255
    /// The maximum value for the `blue` channel
    var blue_max: UInt16 = 255

    /// The amount of bits the `red` channel is shifted to the left
    var red_shift: UInt8 = 16
    /// The amount of bits the `green` channel is shifted to the left
    var green_shift: UInt8 = 8
    /// The amount of bits the `blue` channel is shifted to the left
    var blue_shift: UInt8 = 0

    // Pack with 24 bits of padding
    func pack() -> [UInt8] {
        var packed_data = [UInt8](repeating: 0, count: 16)

        // Bits Per Pixel
        packed_data[0] = self.bits_per_pixel

        // Depth
        packed_data[1] = self.depth

        // BigEndianFlag
        packed_data[2] = self.big_endian_flag ? 1 : 0

        // TrueColorFlag
        packed_data[3] = self.true_color_flag

        // Red, green, blue Max as UInt8
        let red_max = self.red_max.pack(big_endian: self.big_endian_flag)
        let green_max = self.green_max.pack(big_endian: self.big_endian_flag)
        let blue_max = self.blue_max.pack(big_endian: self.big_endian_flag)

        // Red
        packed_data[4] = red_max[0]
        packed_data[5] = red_max[1]

        // Green
        packed_data[6] = green_max[0]
        packed_data[7] = green_max[1]

        // Blue
        packed_data[8] = blue_max[0]
        packed_data[9] = blue_max[1]

        // Red shift
        packed_data[10] = self.red_shift

        // Green shift
        packed_data[11] = self.green_shift

        // Blue shift
        packed_data[12] = self.blue_shift

        // Padding
        packed_data[13] = 0
        packed_data[14] = 0
        packed_data[15] = 0
        return packed_data
    }

    /// Unpacks a RFBPixelFormat struct from the supplied `16` bytes of data
    /// - Parameter data: The array of `UInt8` to unpack
    /// - Returns: The unpacked `VRFBPixelFormat` or `nil` if the byte count is invalid
    static func unpack(data: [UInt8]) -> VRFBPixelFormat? {
        if data.count != 16  {
            return nil
        }

        var res = VRFBPixelFormat()

        res.bits_per_pixel = data[0]
        res.depth = data[1]
        res.big_endian_flag = data[2] != 0
        res.true_color_flag = data[3]

        // We can force unwrap these since we check for length at the beginning
        res.red_max = UInt16.unpack(Array(data[4...5]), big_endian: res.big_endian_flag)!
        res.green_max = UInt16.unpack(Array(data[6...7]), big_endian: res.big_endian_flag)!
        res.blue_max = UInt16.unpack(Array(data[8...9]), big_endian: res.big_endian_flag)!

        res.red_shift = data[10]
        res.green_shift = data[11]
        res.blue_shift = data[12]

        // And 3 bytes of padding to ignore

        return res
    }
}

/// A request struct for requesting a new framebuffer update
struct VRFBFBUpdateRequest {
    /// If the framebuffer request is incremental (partial updates possible)
    var incremental: Bool = false
    /// The x position of the rectangle of interest
    var x_pos: UInt16 = 0
    /// The y position of the rectangle of interest
    var y_pos: UInt16 = 0
    /// The width the rectangle of interest
    var width: UInt16 = 0
    /// The height of the rectangle of interest
    var height: UInt16 = 0

    /// Unpacks a RFBFBUpdateRequest struct from the supplied `16` bytes of data
    /// - Parameter data: The array of `UInt8` to unpack
    /// - Returns: The unpacked `VRFBFBUpdateRequest` or `nil` if the byte count is invalid
    static func unpack(data: [UInt8]) -> VRFBFBUpdateRequest? {
        if data.count != 9 {
            return nil
        }

        var res = VRFBFBUpdateRequest()

        res.incremental = data[0] > 0

        // We can force unwrap these since we check for length at the beginning
        res.x_pos = UInt16.unpack(Array(data[1...2]))!
        res.y_pos = UInt16.unpack(Array(data[3...4]))!
        res.width = UInt16.unpack(Array(data[5...6]))!
        res.height = UInt16.unpack(Array(data[7...8]))!

        return res
    }
}

/// A KeyEvent struct
struct VRFBKeyEvent {
    /// Indicates the state of the key, `true` means pressed, `false` means released
    var down_flag: Bool = false
    /// The X.Org key symbol
    var key_sym: UInt32 = 0

    /// Unpacks a RFBKeyEvent struct from the supplied `7` bytes of data
    /// - Parameter data: The array of `UInt8` to unpack
    /// - Returns: The unpacked `VRFBKeyEvent` or `nil` if the byte count is invalid
    static func unpack(data: [UInt8]) -> VRFBKeyEvent? {
        if data.count != 7 {
            return nil
        }

        var res = VRFBKeyEvent()
        res.down_flag = data[0] > 0

        res.key_sym = UInt32.unpack(Array(data[3...6]))!
        return res
    }
}

/// A PointerEvent struct
struct VRFBPointerEvent {
    /// All 8 mouse button states
    var pressed_buttons: Buttons

    /// The x position within the framebuffer
    var x_position: UInt16 = 0
    /// The y position within the framebuffer
    var y_position: UInt16 = 0

    /// Unpacks a RFBPointerEvent struct from the supplied `5` bytes of data
    /// - Parameter data: The array of `UInt8` to unpack
    /// - Returns: The unpacked `VRFBPointerEvent` or `nil` if the byte count is invalid
    static func unpack(data: [UInt8]) -> VRFBPointerEvent? {
        if data.count != 5 {
            return nil
        }

        var res = VRFBPointerEvent(pressed_buttons: Buttons(data: data[0]))
        res.x_position = UInt16.unpack(Array(data[1...2]))!
        res.y_position = UInt16.unpack(Array(data[3...4]))!
        return res
    }

    /// The buttons of a mouse
    struct Buttons {
        /// The left mouse button
        let button_left: Bool
        /// The middle mouse button
        let button_middle: Bool
        /// The right mouse button
        let button_right: Bool

        /// Scrolled upwards
        let wheel_up: Bool
        /// Scrolled downwards
        let wheel_down: Bool
        /// Scrolled left
        let wheel_left: Bool
        /// Scrolled right
        let wheel_right: Bool

        init(data: UInt8){
            self.button_left = (data & 1) != 0
            self.button_middle = ((data >> 1) & 1) != 0
            self.button_right = ((data >> 2) & 1) != 0

            self.wheel_up = ((data >> 3) & 1) != 0
            self.wheel_down = ((data >> 4) & 1) != 0
            self.wheel_left = ((data >> 5) & 1) != 0
            self.wheel_right = ((data >> 6) & 1) != 0
        }
    }

    /// Returns the `NSEvent.EventType` for this pointer event
    /// for dragging events
    func get_move_eventtype() -> NSEvent.EventType {
        let bt = self.pressed_buttons

        if bt.button_left {
            return .leftMouseDragged
        } else if bt.button_middle {
            return .otherMouseDragged
        } else if bt.button_right {
            return .rightMouseDragged
        }

        return .mouseMoved
    }

}


/// A rectangle describing a rectangular area of the framebuffer that gets updated
struct VRFBRect {
    /// The cropped image to pack and send
    let image: CGImage

    /// Creates a RFBRect from the supplied image, ready to be packed
    init (image: CGImage) {
        self.image = image
    }

    // TODO: Optimize this function
    /// Packs this rect to prepare it for transmission
    /// - Parameter px_format: The pixel format to use for transmission
    /// - Returns: An array of UInt8 to be sent to the client
    func pack(px_format: VRFBPixelFormat) -> [UInt8] {
        // The color format of an CGImage is BGRA?
        let bytes_per_px = UInt8(px_format.bits_per_pixel / 8)
        var data = Array<UInt8>()

        data.insert(contentsOf: UInt16(0).pack(), at: 0)
        data.insert(contentsOf: UInt16(0).pack(), at: 2)
        data.insert(contentsOf: UInt16(self.image.width).pack(), at: 4)
        data.insert(contentsOf: UInt16(self.image.height).pack(), at: 6)

        // Encoding is 0 (RAW) for now
        data.insert(contentsOf: UInt32(0).pack(), at: 8)

        // For now, this only works with 32 bpp
        // TODO: Implement other pixel formats
        if px_format.bits_per_pixel == 32 {
            let cfdata = self.image.dataProvider!.data!

            let data_array = [UInt8](cfdata as Data)

            let newImageSize = (Int(self.image.width) * Int(self.image.height)) * 4

            // Check if the two sizes match up, else send a grey picture.
            // This will most commonly happen when MacOS scales our VM window around and the
            // real dimensions change
            if newImageSize != data_array.count {
                VWarn("Invalid image size: expected \(newImageSize) for delivery, got \(data_array.count)")
                data.append(contentsOf: Array<UInt8>(repeating: 0x55, count: newImageSize))
            } else {
                data.append(contentsOf: data_array)
            }
        }
        return data
    }
}
