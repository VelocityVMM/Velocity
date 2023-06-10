//
//  vRFBUtil.swift
//  velocity
//
//  Created by Max Kofler on 04/06/23.
//

import Foundation
import Socket

/// Packs a `UInt32` value into an array of `UInt8` for use with the RFB protocol
/// - Parameter value: The value to pack
func pack_u32(_ value: UInt32) -> [UInt8] {
    var packed_data = [UInt8](repeating: 0, count: 4)
    packed_data[0] = UInt8(truncatingIfNeeded: (value >> 24) & 0xFF)
    packed_data[1] = UInt8(truncatingIfNeeded: (value >> 16) & 0xFF)
    packed_data[2] = UInt8(truncatingIfNeeded: (value >> 8) & 0xFF)
    packed_data[3] = UInt8(truncatingIfNeeded: value & 0xFF)
    return packed_data
}

/// Unpacks a `UInt32` value from an array of 4 `UInt8` elements
/// - Parameter value: The value to unpack
/// - Returns: The unpacked `UInt32`, `nil` if the array doesn't have enough fields
func unpack_u32(_ value: [UInt8]) -> UInt32? {
    if value.count != 4 {
        return nil;
    }

    return UInt32(value[0]) << 24 | UInt32(value[1]) << 16 | UInt32(value[2]) << 8 | UInt32(value[3]) << 0;
}

/// Packs a `UInt16` value into an array of `UInt8` for use with the RFB protocol
/// - Parameter value: The value to pack
func pack_u16(_ value: UInt16) -> [UInt8] {
    var packed_data = [UInt8](repeating: 0, count: 2)
    packed_data[0] = UInt8(truncatingIfNeeded: (value >> 8) & 0xFF)
    packed_data[1] = UInt8(truncatingIfNeeded: value & 0xFF)
    return packed_data
}

/// Unpacks a `UInt16` value from an array of 2 `UInt8` elements
/// - Parameter value: The value to unpack
/// - Returns: The unpacked `UInt16`, `nil` if the array doesn't have enough fields
func unpack_u16(_ value: [UInt8]) -> UInt16? {
    if value.count != 2 {
        return nil;
    }

    return UInt16(value[0]) << 8 | UInt16(value[1]) << 0;
}

/// Packs a `Int32` value into an array of `UInt8` for use with the RFB protocol
/// - Parameter value: The value to pack
func pack_i32(_ value: Int32) -> [UInt8] {
    var packed_data = [UInt8](repeating: 0, count: 4)
    packed_data[0] = UInt8(truncatingIfNeeded: (value >> 24) & 0xFF)
    packed_data[1] = UInt8(truncatingIfNeeded: (value >> 16) & 0xFF)
    packed_data[2] = UInt8(truncatingIfNeeded: (value >> 8) & 0xFF)
    packed_data[3] = UInt8(truncatingIfNeeded: value & 0xFF)
    return packed_data
}

/// Packs a `Int16` value into an array of `UInt8` for use with the RFB protocol
/// - Parameter value: The value to pack
func pack_i16(_ value: Int32) -> [UInt8] {
    var packed_data = [UInt8](repeating: 0, count: 2)
    packed_data[0] = UInt8(truncatingIfNeeded: (value >> 8) & 0xFF)
    packed_data[1] = UInt8(truncatingIfNeeded: value & 0xFF)
    return packed_data
}

func unpack_u8_bool(value: UInt8) -> [Bool] {
    var booleans: [Bool] = []
    for i in 0..<8 {
        let mask = UInt8(1 << i)
        let bit = value & mask
        booleans.append(bit != 0)
    }
    return booleans
}

extension Array<UInt8> {
    /// Converts the contents of this array to a `Data` value
    /// - Returns: The `Data` object containing a representation of this data
    func data() -> Data {
        return Data(bytes: self, count: self.count);
    }
}

extension Socket {
    func write_arr(_ data: Array<UInt8>) throws {
        // MARK: Debugging can be enabled here by uncommenting the statement
        // Check loglevel here for performance reasons of constructing the string
        /*if VLoglevel.rawValue >= Loglevel.Trace.rawValue {
            VTrace("( <- \(data)", "[\(self.remoteHostname)(\(self.remotePort))]");
        }*/
        try self.write(from: data.data());
    }

    func read_arr() throws -> Array<UInt8> {
        var buffer = Data(capacity: 8192);

        let len = try self.read(into: &buffer);
        if len == 0 {
            return Array();
        }

        let res = Array(buffer[0...len-1]);

        // MARK: Debugging can be enabled here by uncommenting the statement
        // Check loglevel here for performance reasons of constructing the string
        /*if VLoglevel.rawValue >= Loglevel.Trace.rawValue {
            VTrace("( -> \(res)", "[\(self.remoteHostname)(\(self.remotePort))]")
        }*/

        return res;
    }
}
