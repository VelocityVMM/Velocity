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
import Virtualization

extension VZ {

    /// A disk configuration that can be used to create a `VZStorageDeviceConfiguration`
    struct DiskConfiguration {

        /// The piece of media this disk wraps
        let media: VDB.Media
        /// The attachment mode for the disk
        let mode: VDB.TVMDisks.DiskMode
        /// If the disk should be read-only
        let readonly: Bool

        /// Creates a `VZStorageDeviceConfiguration` from this configuration
        func get_storage_device_configuration() throws -> VZStorageDeviceConfiguration {
            // Create the attachment wrapping the disk image
            let attachment = try VZDiskImageStorageDeviceAttachment(
                url: URL(fileURLWithPath: self.media.get_file_path().string), readOnly: self.readonly)

            // Create the storage configurations depending on the disk mode
            switch self.mode {
            case .USB:
                return VZUSBMassStorageDeviceConfiguration(attachment: attachment)
            case .VIRTIO:
                return VZVirtioBlockDeviceConfiguration(attachment: attachment)
            }
        }
    }
}
