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

/// The core management class that all the virtual machines are managed through
class VMManager : Loggable {
    let context = "[VMManager]"

    /// The dictionary to store all virtual machines the manager knows
    /// about. The `VMID` identifies each virtual machine
    var vms: Dictionary<VMID, VirtualMachine> = Dictionary()

    /// The manager for all EFIStores
    let efistore_manager: EFIStoreManager

    /// The Database to use for all operations
    let db: VDB

    /// The timer for the capture events
    var capture_timer: Timer? = nil;
    /// The amount of captures taken in one second
    var capture_fps = 30;
    /// The queue to do the capturing in
    let capture_queue: DispatchQueue;

    /// Initializes the manager and tries to load all virtual machines
    /// - Parameter efistore_manager: The manager for all EFIStores
    /// - Parameter db: The database to use for all operations
    init(efistore_manager: EFIStoreManager, db: VDB) throws {
        self.efistore_manager = efistore_manager
        self.db = db
        self.capture_queue = DispatchQueue(label: "Capture", attributes: .concurrent)

        // Iterate over all virtual machines available in the database
        for vm in try self.db.t_vms.get_all_vms(db: self.db) {

            VDebug("Loading virtual machine '\(vm.name)' [\(vm.vmid)]")

            // Try to load each one
            switch try VirtualMachine.new(vm: vm, manager: self) {
            case .failure(let e):
                VErr("Failed to load virtual machine '\(vm.name)' [\(vm.vmid)]: \(e)")
            case .success(let new_vm):
                self.vms[vm.vmid] = new_vm

                VInfo("Loaded virtual machine '\(vm.name)' [\(vm.vmid)]")

                // If a VM requested autostart, start it now
                if vm.autostart {
                    VInfo("Autostarting virtual machine '\(vm.name)' [\(vm.vmid)]")
                    let _ = try new_vm.request_state_transition(state: .RUNNING)
                }
            }
        }

        // Create the timer to fire in an interval for capture
        self.capture_timer = Timer.scheduledTimer(timeInterval: 1.0 / Double(self.capture_fps), target: self, selector: #selector(self.update_frame), userInfo: nil, repeats: true);
    }

    /// Tries to retrieve a `VirtualMachine` by its `VMID`
    /// - Parameter vmid: The `VMID` of the virtual machine to retrieve
    /// - Returns: The virtual machine if found, else `nil`
    func get_vm(vmid: VMID) -> VirtualMachine? {
        self.vms[vmid]
    }

    @objc func update_frame() {
        // Iterate over all virtual machines
        for vm in self.vms {
            // If the virtual machine has an attached window
            if let window = vm.value.window {
                // Dispatch the work in an asynchronous dispatch queue to parallelize it
                self.capture_queue.async {
                    let _ = window.capture()
                }
            }
        }
    }
}
