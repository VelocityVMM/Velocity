//
//  vRFBStructs.swift
//  velocity
//
//  Created by Max Kofler on 04/06/23.
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

enum VRFBClientCommand : UInt8 {
    case SetPixelFormat = 0
    case SetEncodings = 2
    case FramebufferUpdateRequest = 3
    case KeyEvent = 4
    case PointerEvent = 5
    case ClientCutText = 6
}

/// Some contants defined for global use
struct VRFBConstants{
    /// The security result if the security negotiation was successfull
    static let SECURITY_RESULT_OK: UInt32 = 0;
    /// The security result if the security negotiation failed
    static let SECURITY_RESULT_FAILED: UInt32 = 1;
    /// The security result if the security negotiation failed for too many attempts
    static let SECURITY_RESULT_FAILED_TOO_MANY_ATTEMPTS: UInt32 = 1;
}

/// The RFB pixel format struct.
struct VRFBPixelFormat {
    /// How many bits are needed for representing a pixel in the current format
    var bits_per_pixel: UInt8 = 32
    /// The color depth in bits (8 + 8 + 8) = 24
    var depth: UInt8 = 24
    /// If not `0`, this indicates a big endian format
    var big_endian_flag: UInt8 = 0
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
        packed_data[2] = self.big_endian_flag
        
        // TrueColorFlag
        packed_data[3] = self.true_color_flag
        
        // Red, green, blue Max as UInt8
        let red_max = pack_u16(self.red_max)
        let green_max = pack_u16(self.green_max)
        let blue_max = pack_u16(self.blue_max)
        
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
            return nil;
        }

        var res = VRFBPixelFormat();

        res.bits_per_pixel = data[0];
        res.depth = data[1];
        res.big_endian_flag = data[2];
        res.true_color_flag = data[3];

        // We can force unwrap these since we check for length at the beginning
        res.red_max = unpack_u16(Array(data[4...5]))!;
        res.green_max = unpack_u16(Array(data[6...7]))!;
        res.blue_max = unpack_u16(Array(data[8...9]))!;

        res.red_shift = data[10];
        res.green_shift = data[11];
        res.blue_shift = data[12];

        // And 3 bytes of padding to ignore

        return res;
    }
}

/// A request struct for requesting a new framebuffer update
struct VRFBFBUpdateRequest {
    var incremental: Bool = false;
    var x_pos: UInt16 = 0;
    var y_pos: UInt16 = 0;
    var width: UInt16 = 0;
    var height: UInt16 = 0;

    /// Unpacks a RFBFBUpdateRequest struct from the supplied `16` bytes of data
    /// - Parameter data: The array of `UInt8` to unpack
    /// - Returns: The unpacked `VRFBFBUpdateRequest` or `nil` if the byte count is invalid
    static func unpack(data: [UInt8]) -> VRFBFBUpdateRequest? {
        if data.count != 9 {
            return nil;
        }

        var res = VRFBFBUpdateRequest();

        res.incremental = data[0] > 0;

        // We can force unwrap these since we check for length at the beginning
        res.x_pos = unpack_u16(Array(data[1...2]))!;
        res.y_pos = unpack_u16(Array(data[3...4]))!;
        res.width = unpack_u16(Array(data[5...6]))!;
        res.height = unpack_u16(Array(data[7...8]))!;

        return res;
    }
}

/// A KeyEvent struct
struct VRFBKeyEvent {
    var down_flag: Bool = false;
    var key_sym: UInt32 = 0;

    static func unpack(data: [UInt8]) -> VRFBKeyEvent? {
        if data.count != 7 {
            return nil;
        }

        var res = VRFBKeyEvent();
        res.down_flag = data[0] > 0;

        res.key_sym = unpack_u32(Array(data[3...6]))!;
        return res;
    }
}

/// A PointerEvent struct
struct VRFBPointerEvent {
    // All 8 'Mouse button states'
    var buttons_pressed: [Bool] = [ ];

    // X / Y in the FB
    var x_position: UInt16 = 0
    var y_position: UInt16 = 0

    static func unpack(data: [UInt8]) -> VRFBPointerEvent? {
        if data.count != 5 {
            return nil;
        }

        var res = VRFBPointerEvent();
        // left-click: bool[0], right-click: bool[2]
        res.buttons_pressed = unpack_u8_bool(value: data[0])
        res.x_position = unpack_u16(Array(data[1...2]))!
        res.y_position = unpack_u16(Array(data[3...4]))!
        return res;
    }
}


/// A rectangle describing a rectangular area of the framebuffer that gets updated
struct VRFBRect {
    let dimensions: CGRect;
    let image: CGImage;

    init (image: CGImage, request: VRFBFBUpdateRequest) {
        self.dimensions = CGRect(x: Int(request.x_pos),
                                 y: Int(request.y_pos),
                                 width: Int(request.width),
                                 height: Int(request.height));
        // MARK: Check this unwrap!
        self.image = image.cropping(to: self.dimensions)!;
    }

    func pack(px_format: VRFBPixelFormat) -> [UInt8]{
        // MARK: BGRA
        let bytes_per_px = UInt8(px_format.bits_per_pixel / 8);
        var data = Array<UInt8>(repeating: 0xff, count: Int(self.dimensions.width) * Int(self.dimensions.height) * Int(bytes_per_px))

        data.insert(contentsOf: pack_u16(UInt16(self.dimensions.minX)), at: 0);
        data.insert(contentsOf: pack_u16(UInt16(self.dimensions.minY)), at: 2);
        data.insert(contentsOf: pack_u16(UInt16(self.dimensions.width)), at: 4);
        data.insert(contentsOf: pack_u16(UInt16(self.dimensions.height)), at: 6);

        // Encoding is 0 (RAW) for now
        data.insert(contentsOf: pack_i32(0), at: 8);

        // MARK: React only to 32bit color depth for now (DIRTY)
        if px_format.bits_per_pixel == 32 {

            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let newImageSize = UInt32(self.image.width) * UInt32(self.image.height);
            data.reserveCapacity(data.count + Int(newImageSize*4));
            var pixelData = [UInt8](repeating: 0xff, count: Int(newImageSize*4));

            guard let newContext = CGContext(data: &pixelData, width: self.image.width, height: self.image.height, bitsPerComponent: self.image.bitsPerComponent, bytesPerRow: self.image.bytesPerRow, space: colorSpace, bitmapInfo: self.image.bitmapInfo.rawValue) else {
                fatalError("Failed to create new CGContext")
            }

            // Draw the original image onto the new CGImage
            newContext.draw(self.image, in: CGRect(x: 0, y: 0, width: self.image.width, height: self.image.height));

            // And now insert the pixels into the array
            for px in stride(from: 0, through: pixelData.count-1, by: 4) {
                // MARK: Dirty hack to get it to work for now...
                data[12 + px] = pixelData[px];
                data[12 + px + 1] = pixelData[px + 1];
                data[12 + px + 2] = pixelData[px + 2];
            };
        }
        return data;
    }
}
