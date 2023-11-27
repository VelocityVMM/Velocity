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
import Virtualization

/// A wrapper around the `VZVirtualMachineConfiguration` with some useful
/// safeguards and sensible error handling
class VirtualMachineConfiguration : VZVirtualMachineConfiguration, Loggable {
    var context: String = "[VMConfiguration]"

    /// Make the constructor private, allow only static initialization
    private override init() {}

    /// Creates a new VirtualMachineConfiguration from a `VDB.VM`
    /// using its properties for the VZVirtualMachineConfiguration
    /// - Parameter vm: The VDB.VM struct to use for configuration
    /// - Parameter manager: The manager to use for retrieving the EFIStore
    ///
    /// This function should probably change for a new signature that allows non-critical
    /// errors to be returned to inform the manager about errors that arose but did not
    /// prevent virtual machine creation
    static func new(vm: VDB.VM, manager: VMManager) throws -> Result<VirtualMachineConfiguration, ConfigurationError> {
        let config = VirtualMachineConfiguration()
        config.context = "[VMConfiguration (\(vm.name))]"

        // Set the CPUs
        if let e = config.set_cpu_count(cpu_count: Int(vm.cpu_count)).get_failure() {
            return .failure(.CPUCount(e))
        }

        // Set the memory
        if let e = config.set_memory_size(memory_size_mib: vm.memory_size_mib).get_failure() {
            return .failure(.MemorySize(e))
        }

        // Setup the bootloader
        let bootloader = VZEFIBootLoader()
        bootloader.variableStore = try manager.efistore_manager.get_efistore(vmid: vm.vmid)
        config.bootLoader = bootloader

        // Setup the disks, printing errors
        let disks = try vm.db.t_vmdisks.select_vm_disks(vm: vm)
        for error in disks.1 {
            config.VErr("Failed to load disk for vm \"\(vm.name)\" [\(vm.vmid)]: \(error)")
        }
        for disk in disks.0 {
            config.storageDevices.append(try disk.get_storage_device_configuration())
            config.VDebug("Attached media \"\(disk.media.name)\" {\(disk.media.mid)} via \(disk.mode)")
        }

        let nics = try vm.db.t_vmnics.select_vm_nics(vm: vm)
        for error in nics.1 {
            config.VErr("Failed to load NIC for vm \"\(vm.name)\" [\(vm.vmid)]: \(error)")
        }
        for nic in nics.0 {
            config.networkDevices.append(nic.get_network_device_configuration())
            config.VDebug("Attached NIC of type \(nic)")
        }

        // Setup the displays
        let displays = try vm.db.t_vmdisplays.select_vm_displays(vm: vm)
        if let display = displays.last {
            let gpu = VZVirtioGraphicsDeviceConfiguration()
            gpu.scanouts.append(display.get_scanout())
            config.graphicsDevices.append(gpu)
        }
        // Warn the user that currently only 1 display is possible
        if displays.count > 1 {
            config.VWarn("Virtualization framework does not allow for more than 1 display")
        }

        return .success(config)
    }

    /// Tries to validate this configuration and packages an error into a `ConfigurationError`
    func try_validate() -> Result<Void, ConfigurationError> {
        do {
            try self.validate()
        } catch let e {
            return .failure(.Validate(e))
        }

        return .success(())
    }

    /// Try setting the CPU count
    /// - Parameter cpu_count: The amount of CPU cores to assign
    func set_cpu_count(cpu_count: Int) -> Result<Void, CPUCountError> {
        let min = Self.minimumAllowedCPUCount
        let max = Self.maximumAllowedCPUCount

        guard cpu_count >= min && cpu_count <= max else {
            return .failure(CPUCountError(min: min, max: max, cur: cpu_count))
        }

        self.cpuCount = cpu_count
        return .success(())
    }

    /// Try setting the memory size in MiB
    /// - Parameter memory_size_mib: The size to set
    func set_memory_size(memory_size_mib: UInt64) -> Result<Void, MemorySizeError> {
        let min = Self.minimumAllowedMemorySize
        let max = Self.maximumAllowedMemorySize

        // Convert the memory size into MiB (Mebibytes)
        let memory_size = memory_size_mib * 1_048_576

        guard memory_size >= min && memory_size <= max else {
            return .failure(MemorySizeError(min: min, max: max, cur: memory_size))
        }

        self.memorySize = memory_size
        return .success(())
    }

    /// An error that can occur during configuration
    enum ConfigurationError : Error, CustomStringConvertible {
        /// The CPU count is not allowed
        case CPUCount(VirtualMachineConfiguration.CPUCountError)
        /// The memory configuration is not allowed
        case MemorySize(VirtualMachineConfiguration.MemorySizeError)
        /// The VZVirtualMachineConfiguraion is invalid
        case Validate(Error)

        var description: String {
            var res = "Configuration invalid: "

            switch self {
            case .CPUCount(let e):
                res.append("Invalid CPU count configuration: value \(e.cur) is not within \(e.min) <-> \(e.max)")
            case .MemorySize(let e):
                res.append("Invalid memory configuration: value \(e.cur) is not within \(e.min) <-> \(e.max)")
            case .Validate(let e):
                res.append("Configuration validation failed: \(e.localizedDescription)")
            }

            return res
        }
    }

    /// The error that gets returned if the CPU core assignment fails
    struct CPUCountError : Error {
        /// The minimum amount of CPU cores needed
        let min: Int
        /// The maximum amount of CPU cores allowed
        let max: Int
        /// The amount of CPU cores tried to assign
        let cur: Int
    }

    /// The error that gets returned if the memory assignment fails
    struct MemorySizeError : Error {
        /// The minimum amount of memory needed
        let min: UInt64
        /// The maximum amount of memory allowed
        let max: UInt64
        /// The amount of memory specified by the configuration
        let cur: UInt64
    }
}
