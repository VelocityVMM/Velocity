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

extension UInt32 {
    /// Packs the `UInt32` value into an array of `UInt8` for use with the RFB protocol
    /// - Parameter big_endian: `true` for big endian output, `false` for little endian output
    /// - Returns: The array of `UInt8`s for transmission
    func pack(big_endian: Bool = false) -> [UInt8] {
        var packed_data = [UInt8](repeating: 0, count: 4)

        if big_endian {
            packed_data[0] = UInt8(truncatingIfNeeded: self & 0xFF)
            packed_data[1] = UInt8(truncatingIfNeeded: (self >> 8) & 0xFF)
            packed_data[2] = UInt8(truncatingIfNeeded: (self >> 16) & 0xFF)
            packed_data[3] = UInt8(truncatingIfNeeded: (self >> 24) & 0xFF)
        } else {
            packed_data[0] = UInt8(truncatingIfNeeded: (self >> 24) & 0xFF)
            packed_data[1] = UInt8(truncatingIfNeeded: (self >> 16) & 0xFF)
            packed_data[2] = UInt8(truncatingIfNeeded: (self >> 8) & 0xFF)
            packed_data[3] = UInt8(truncatingIfNeeded: self & 0xFF)
        }

        return packed_data
    }

    /// Unpacks a `UInt32` value from an array of 4 `UInt8` elements
    /// - Parameter value: The array to unpack
    /// - Parameter big_endian: `true` for big endian input, `false` for little endian input
    /// - Returns: The unpacked `UInt32`, `nil` if the array doesn't have enough fields
    static func unpack(_ value: [UInt8], big_endian: Bool = false) -> Self? {
        if value.count != 4 {
            return nil
        }

        if big_endian {
            return UInt32(value[3]) << 24 | UInt32(value[2]) << 16 | UInt32(value[1]) << 8 | UInt32(value[0]) << 0
        } else {
            return UInt32(value[0]) << 24 | UInt32(value[1]) << 16 | UInt32(value[2]) << 8 | UInt32(value[3]) << 0
        }
    }
}

extension Int32 {
    /// Packs the `Int32` value into an array of `UInt8` for use with the RFB protocol
    /// - Parameter big_endian: `true` for big endian output, `false` for little endian output
    /// - Returns: The array of `UInt8`s for transmission
    func pack(big_endian: Bool = false) -> [UInt8] {
        var packed_data = [UInt8](repeating: 0, count: 4)

        if big_endian {
            packed_data[0] = UInt8(truncatingIfNeeded: self & 0xFF)
            packed_data[1] = UInt8(truncatingIfNeeded: (self >> 8) & 0xFF)
            packed_data[2] = UInt8(truncatingIfNeeded: (self >> 16) & 0xFF)
            packed_data[3] = UInt8(truncatingIfNeeded: (self >> 24) & 0xFF)
        } else {
            packed_data[0] = UInt8(truncatingIfNeeded: (self >> 24) & 0xFF)
            packed_data[1] = UInt8(truncatingIfNeeded: (self >> 16) & 0xFF)
            packed_data[2] = UInt8(truncatingIfNeeded: (self >> 8) & 0xFF)
            packed_data[3] = UInt8(truncatingIfNeeded: self & 0xFF)
        }

        return packed_data
    }

    /// Unpacks a `Int32` value from an array of 4 `UInt8` elements
    /// - Parameter value: The array to unpack
    /// - Parameter big_endian: `true` for big endian input, `false` for little endian input
    /// - Returns: The unpacked `Int32`, `nil` if the array doesn't have enough fields
    static func unpack(_ value: [UInt8], big_endian: Bool = false) -> Self? {
        if value.count != 4 {
            return nil
        }

        if big_endian {
            return Int32(value[3]) << 24 | Int32(value[2]) << 16 | Int32(value[1]) << 8 | Int32(value[0]) << 0
        } else {
            return Int32(value[0]) << 24 | Int32(value[1]) << 16 | Int32(value[2]) << 8 | Int32(value[3]) << 0
        }
    }
}

extension UInt16 {
    /// Packs the `UInt16` value into an array of `UInt8` for use with the RFB protocol
    /// - Parameter big_endian: `true` for big endian output, `false` for little endian output
    /// - Returns: The array of `UInt8`s for transmission
    func pack(big_endian: Bool = false) -> [UInt8] {
        var packed_data = [UInt8](repeating: 0, count: 2)

        if big_endian {
            packed_data[0] = UInt8(truncatingIfNeeded: self & 0xFF)
            packed_data[1] = UInt8(truncatingIfNeeded: (self >> 8) & 0xFF)
        } else {
            packed_data[0] = UInt8(truncatingIfNeeded: (self >> 8) & 0xFF)
            packed_data[1] = UInt8(truncatingIfNeeded: self & 0xFF)
        }

        return packed_data
    }

    /// Unpacks a `UInt16` value from an array of 4 `UInt8` elements
    /// - Parameter value: The array to unpack
    /// - Parameter big_endian: `true` for big endian input, `false` for little endian input
    /// - Returns: The unpacked `UInt16`, `nil` if the array doesn't have enough fields
    static func unpack(_ value: [UInt8], big_endian: Bool = false) -> Self? {
        if value.count != 2 {
            return nil
        }

        if big_endian {
            return UInt16(value[1]) << 8 | UInt16(value[0]) << 0
        } else {
            return UInt16(value[0]) << 8 | UInt16(value[1]) << 0
        }
    }
}

extension Int16 {
    /// Packs the `Int16` value into an array of `UInt8` for use with the RFB protocol
    /// - Parameter big_endian: `true` for big endian output, `false` for little endian output
    /// - Returns: The array of `UInt8`s for transmission
    func pack(big_endian: Bool = false) -> [UInt8] {
        var packed_data = [UInt8](repeating: 0, count: 2)

        if big_endian {
            packed_data[0] = UInt8(truncatingIfNeeded: self & 0xFF)
            packed_data[1] = UInt8(truncatingIfNeeded: (self >> 8) & 0xFF)
        } else {
            packed_data[0] = UInt8(truncatingIfNeeded: (self >> 8) & 0xFF)
            packed_data[1] = UInt8(truncatingIfNeeded: self & 0xFF)
        }

        return packed_data
    }

    /// Unpacks a `Int16` value from an array of 4 `UInt8` elements
    /// - Parameter value: The array to unpack
    /// - Parameter big_endian: `true` for big endian input, `false` for little endian input
    /// - Returns: The unpacked `Int16`, `nil` if the array doesn't have enough fields
    static func unpack(_ value: [UInt8], big_endian: Bool = false) -> Self? {
        if value.count != 2 {
            return nil
        }

        if big_endian {
            return Int16(value[1]) << 8 | Int16(value[0]) << 0
        } else {
            return Int16(value[0]) << 8 | Int16(value[1]) << 0
        }
    }
}

extension Array<UInt8> {
    /// Converts the contents of this array to a `Data` value
    /// - Returns: The `Data` object containing a representation of this data
    func data() -> Data {
        return Data(bytes: self, count: self.count)
    }
}
