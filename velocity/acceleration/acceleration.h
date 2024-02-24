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

///
/// Acceleration functions for making some things faster.
///
/// Swift is nice, but sometimes, good old `C`-style control over pointers
/// and data is needed to achieve the wanted performance reliably.
/// This module contains such functions.
///

#include <stdint.h>

/// Packs the supplied `data` into the correct pixel format for `24` bit color depth rgba
/// - Parameter data: The array of pixel data to mutate
/// - Parameter len: The length of the data in bytes
/// - Parameter offset_r: The left shift of the `R` channel in bits
/// - Parameter offset_g: The left shift of the `G` channel in bits
/// - Parameter offset_b: The left shift of the `B` channel in bits
/// - Parameter offset_a: The left shift of the `A` channel in bits
///
/// This function assumes the source pixel data is in `BGRA` format
void pack_rfb_pixels_rgba32(
                            uint8_t * data,
                            size_t len,
                            uint8_t shift_r,
                            uint8_t shift_g,
                            uint8_t shift_b,
                            uint8_t shift_a
                            );
