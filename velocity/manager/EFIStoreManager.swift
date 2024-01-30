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
import System
import Virtualization

class EFIStoreManager : Loggable {
    let context = "[EFIStore]"

    /// The root to store the EFIStores in
    let root: FilePath

    init(efistore_dir: FilePath) throws {
        self.root = efistore_dir

        let manager = FileManager.default
        var is_dir: ObjCBool = false

        // Check if the destination exists
        if manager.fileExists(atPath: efistore_dir.string, isDirectory: &is_dir) {
            // If it is not a directory, error out
            if !is_dir.boolValue {
                VErr("EFIStore location '\(efistore_dir)' does exist, but is not a directory")
                throw CreationError("EFIStore location '\(efistore_dir)' does exist, but is not a directory")
            }
        } else {
            // If it doesn't exist, create the new directory
            VInfo("Creating new EFIStore directory at '\(efistore_dir)'")
            try manager.createDirectory(at: URL(filePath: efistore_dir.string), withIntermediateDirectories: true)
        }

        VInfo("Initialized EFIStore directory at '\(efistore_dir)'")
    }

    /// An error occured during pool creation
    struct CreationError: Error, LocalizedError {
        let errorDescription: String?

        init(_ description: String) {
            errorDescription = description
        }
    }

    /// Retrieves an `EFIVariableStore` from the manager, creating one if necessary
    /// - Parameter vmid: The ID of the virtual machine to get the EFIStore for
    func get_efistore(vmid: VMID) throws -> VZEFIVariableStore {
        let manager = FileManager.default

        let file_url = self.root.appending("efistore_vm_\(vmid)")

        if manager.fileExists(atPath: file_url.string) {
            VDebug("Using existing EFIStore '\(file_url.string)' for VMID=\(vmid)")
            return VZEFIVariableStore(url: URL(filePath: file_url.string))
        } else {
            VDebug("Creating new EFIStore '\(file_url.string)' for VMID=\(vmid)")
            return try VZEFIVariableStore(creatingVariableStoreAt: URL(filePath: file_url.string))
        }
    }
}
