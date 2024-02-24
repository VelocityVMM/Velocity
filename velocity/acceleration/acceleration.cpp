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
/// Implementation of acceleration functions
///

#include <stdio.h>
#include <stdint.h>

/// Packs the provided data according to the supplied pixel format
extern "C" void pack_rfb_pixels_rgba32(
                                       uint8_t * data,
                                       size_t len,
                                       uint8_t shift_r,
                                       uint8_t shift_g,
                                       uint8_t shift_b,
                                       uint8_t shift_a) {

    // Create some cache variables
    uint8_t r, g, b, a = 0;

    // Iterate over all pixels
    for (size_t i = 0; i < len; i += 4) {

        // Create a pointer for extra speedy access
        uint8_t* ptr = data + i;

        b = *ptr;
        g = *(ptr+1);
        r = *(ptr+2);
        a = *(ptr+3);

        // Reinterpret the pointer as 32 bit and shift the new values into it
        *(uint32_t*)ptr = (a << shift_a) | (r << shift_r) | (g << shift_g) | (b << shift_b);
    }

    return;
}
