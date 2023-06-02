//
//  Simple Interface to Virtualization.framework
//  velocity
//
//  Created by zimsneexh on 24.05.23.
//

import Foundation
import Virtualization

internal struct VelocityVZError: Error, LocalizedError {
    let errorDescription: String?

    init(_ description: String) {
        errorDescription = description
    }
}

internal struct Disk: Codable {
    var name: String
    var size_mb: UInt64
    
    init(name: String, size_mb: UInt64) {
        self.name = name
        self.size_mb = size_mb
    }
}

public struct VMProperties: Codable {
    var name: String
    var cpu_count: Int
    var machine_type: String
    var iso_image_path: String?
    var rosetta: Bool
    var disks: Array<Disk>
    var memory_size: UInt64
    var screen_size: NSSize

    init(name: String, cpu_count: Int, memory_size: UInt64, machine_type: String, iso_image_path: String, rosetta: Bool, disks: Array<Disk>, screen_size: NSSize) {
        self.name = name
        self.cpu_count = cpu_count
        self.memory_size = memory_size
        self.machine_type = machine_type
        self.iso_image_path = iso_image_path
        self.rosetta = rosetta
        self.disks = disks
        self.screen_size = screen_size;
    }
    
    func as_json() throws  -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let data = try encoder.encode(self)
            return String(decoding: data, as: UTF8.self)
        } catch {
            throw VelocityVZError("Could not decode as JSON")
        }
    }
    
    func validate() throws {
        if(!FileManager.default.fileExists(atPath: self.iso_image_path!)) {
            throw VelocityVZError("Could not find ISO-Image.")
        }
        
        let available_cpus = ProcessInfo.processInfo.processorCount
        if(available_cpus < self.cpu_count) {
            throw VelocityVZError("Cannot allocate more CPUs than are available.")
        }
    }
    
    func write(atPath: String) throws {
        do {
            try self.as_json().write(toFile: atPath, atomically: true, encoding: String.Encoding.utf8)
        } catch {
            throw VelocityVZError(error.localizedDescription)
        }
    }
}

//
// Create a new virtual machine with
// given Struct
//
public func deploy_vm(velocity_config: VelocityConfig, vm_properties: VMProperties) throws {
    let bundle_path = velocity_config.velocity_bundle_dir.appendingPathComponent("/\(vm_properties.name).bundle/")
    
    VInfo("Creating new virtual machine '\(vm_properties.name)' at \(bundle_path.absoluteString) ..")
    // Check if already exists?
    if(FileManager.default.fileExists(atPath: bundle_path.absoluteString)) {
        throw VelocityVZError("Could not create VM because a VM with this name already exists.")
    }
        
    // Create a VM Bundle
    VDebug("Creating Bundle at \(bundle_path)..")
    if(!create_directory_safely(path: bundle_path.absoluteString)) {
        throw VelocityVZError("Could not create VM bundle directory.")
    }
    
    // Write bundle json file to disk
    VDebug("Writing VM.json to disk..")
    do {
        try vm_properties.write(atPath: bundle_path.appendingPathComponent("Velocity.json").absoluteString)
    } catch {
        throw VelocityVZError(error.localizedDescription)
    }
    
    // Create MachineIdentifier
    let machine_identifier_path = bundle_path.appendingPathComponent("MachineIdentifier").absoluteString

    switch(vm_properties.machine_type) {
    case "MAC":
        throw VelocityVZError("Machine type not implemented.");
        
    case "EFI_BOOTLOADER":
        if(!new_generic_machine_identifier(pathTo: machine_identifier_path)) {
            throw VelocityVZError("Could not create machine identifier.");
        }
        
        let efi_stor_path = bundle_path.appendingPathComponent("NVRAM").absoluteString
        
        guard let _ = try? VZEFIVariableStore(creatingVariableStoreAt: URL(fileURLWithPath: efi_stor_path)) else {
            throw VelocityVZError("Could not create EFI Variable storage in bundle.")
        }
        
    case "KERNEL_BOOT":
        throw VelocityVZError("Machine type not implemented.");
    
    default:
        throw VelocityVZError("Unknown machine type.")
    }
    
    VInfo("Creating Disk Image(s)..")
    for disk in vm_properties.disks {
        do {
            try create_disk_image(pathTo: bundle_path.absoluteString, disk: disk)
        } catch {
            throw VelocityVZError("Error: \(error.localizedDescription)")
        }
    }
}

public func start_vm_by_name(velocity_config: VelocityConfig, vm_name: String) throws -> VLVirtualMachine {
    let bundle_path = velocity_config.velocity_bundle_dir.appendingPathComponent("/\(vm_name).bundle/")

    if(!FileManager.default.fileExists(atPath: bundle_path.path)) {
        throw VelocityVZError("Could not find VM by name '\(vm_name)'")
    }
    
    var file_content: String;
    do {
        file_content = try String(contentsOfFile: bundle_path.appendingPathComponent("Velocity.json").path, encoding: .utf8)
    } catch {
        throw VelocityVZError("Could not read VM definition: \(error)")
    }
    
    let decoder = JSONDecoder()
    let vm_info = try decoder.decode(VMProperties.self, from: Data(file_content.utf8))
    let vm_disks = NSMutableArray()
    
    // Setup the VM
    let virtual_machine_config = VZVirtualMachineConfiguration()
    virtual_machine_config.cpuCount = vm_info.cpu_count
    virtual_machine_config.memorySize = (vm_info.memory_size * 1024 * 1024)
    
    virtual_machine_config.keyboards = [VZUSBKeyboardConfiguration()]
    virtual_machine_config.pointingDevices = [VZUSBScreenCoordinatePointingDeviceConfiguration()]
    
    VDebug("Selected Machine type is \(vm_info.machine_type)")
    switch(vm_info.machine_type) {
    case "EFI_BOOTLOADER":
        let platform = VZGenericPlatformConfiguration()
        let bootloader = VZEFIBootLoader()
        
        // Check for EFI Store and import it
        VDebug("Checking for NVRAM..")
        if !FileManager.default.fileExists(atPath: bundle_path.appendingPathComponent("NVRAM").absoluteString) {
            throw VelocityVZError("EFI variable store does not exist.")
        }
        
        bootloader.variableStore = VZEFIVariableStore(url: bundle_path.appendingPathComponent("NVRAM"))
        
        VDebug("NVRAM set.")
        VDebug("Checking for MachineIdentifier..")
        guard let machine_identifier_data = try? Data(contentsOf: URL(fileURLWithPath: bundle_path.appendingPathComponent("MachineIdentifier").absoluteString)) else {
            throw VelocityVZError("Failed to retrieve machine identifier data.")
        }
        
        VDebug("Setting MachineIdentifier..")
        guard let machine_identifier = VZGenericMachineIdentifier(dataRepresentation: machine_identifier_data) else {
            throw VelocityVZError("Could not load Machine Identifier data.")
        }
        platform.machineIdentifier = machine_identifier
        VDebug("EFI Setup completed.")
        
        virtual_machine_config.platform = platform
        virtual_machine_config.bootLoader = bootloader
        
        virtual_machine_config.memoryBalloonDevices = [VZVirtioTraditionalMemoryBalloonDeviceConfiguration()]
        virtual_machine_config.entropyDevices = [VZVirtioEntropyDeviceConfiguration()]
        
        VDebug("Adding Virtio Graphics..")
        let graphics_device = VZVirtioGraphicsDeviceConfiguration()
        graphics_device.scanouts = [
            VZVirtioGraphicsScanoutConfiguration(widthInPixels: 1920, heightInPixels: 1080)
        ]
        virtual_machine_config.graphicsDevices = [ graphics_device ]
        
    case "KERNEL_BOOT":
        break
        
    case "MAC":
        VDebug("???")
        break
        
    default:
        break
    }
    
    if(vm_info.iso_image_path != nil) {
        VDebug("Attaching ISO image at path \(vm_info.iso_image_path!)..")
        guard let installer_disk_attachment = try? VZDiskImageStorageDeviceAttachment(url: URL(fileURLWithPath: vm_info.iso_image_path!), readOnly: true) else {
            throw VelocityVZError("Could not attach ISO image to VM")
        }
        vm_disks.add(VZUSBMassStorageDeviceConfiguration(attachment: installer_disk_attachment))
    }
    
    guard let disks = vm_disks as? [VZStorageDeviceConfiguration] else {
        throw VelocityVZError("Invalid disksArray.")
    }
    virtual_machine_config.storageDevices = disks
    
    do {
        VDebug("Validating Machine Configuration.")
        try virtual_machine_config.validate()
        VDebug("Machine configuration is valid! Starting..")
    } catch {
        throw VelocityVZError("Virtual Machine configuration is invalid: \(error)")
    }
    
    let vvm = VLVirtualMachine(vm_config: virtual_machine_config, vm_info: vm_info);

    vvm.start { (result) in
        VDebug("Hypervisor callback..")
        
        if case let .failure(error) = result {
            print("Failed to start the virtual machine. \(error)")
            exit(EXIT_FAILURE)
        }
    }

    return vvm;
}

//MARK: send key to vm, PoC for VNC Server implementation..
func send_key_event_to_vm(to vm_view: NSView, key_code: UInt16) {
    let key_event = NSEvent.keyEvent(with: .keyDown, location: NSPoint.zero, modifierFlags: [], timestamp: TimeInterval(), windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: key_code)
    
    let key_release_event = NSEvent.keyEvent(with: .keyUp, location: NSPoint.zero, modifierFlags: [], timestamp: TimeInterval(), windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: key_code)
    
    // Execute keyDown immediately
    if let key_event = key_event {
        DispatchQueue.main.async {
            vm_view.keyDown(with: key_event)
        }
    }
    
    //Execute keyUp with 0.1 delay
    if let key_release_event = key_release_event {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            vm_view.keyUp(with: key_release_event)
        }
    }
}

internal func create_disk_image(pathTo: String, disk: Disk) throws {
    let disk_path = pathTo + "/\(disk.name).img"
    
    //MARK: check if disk name is valid.
    
    if !FileManager.default.createFile(atPath: disk_path, contents: nil, attributes: nil) {
        throw VelocityVZError("Could not write disk image to file.")
    }
    
    guard let main_disk = try? FileHandle(forWritingTo: URL(fileURLWithPath: disk_path)) else {
        throw VelocityVZError("Could not open the disk image for writing.")
    }

    do {
        try main_disk.truncate(atOffset: disk.size_mb * 1024 * 1024)
        VInfo("Disk image created at \(disk_path).")
    } catch {
        throw VelocityVZError("Could not truncate the VM's main disk image.")
    }
}

private func createSpiceAgentConsoleDeviceConfiguration() -> VZVirtioConsoleDeviceConfiguration {
        let consoleDevice = VZVirtioConsoleDeviceConfiguration()

        let spiceAgentPort = VZVirtioConsolePortConfiguration()
        spiceAgentPort.name = VZSpiceAgentPortAttachment.spiceAgentPortName
        spiceAgentPort.attachment = VZSpiceAgentPortAttachment()
        consoleDevice.ports[0] = spiceAgentPort

        return consoleDevice
}

internal func new_generic_machine_identifier(pathTo: String) -> Bool {
    VDebug("Creating VZGenericMachineIdentifier..")
    let machine_identifier = VZGenericMachineIdentifier()
    
    do {
        try machine_identifier.dataRepresentation.write(to: URL(fileURLWithPath: pathTo))
    } catch {
        VErr("Could not write bundle file to disk.")
        return false;
    }
    return true;
}


func createConsoleConfiguration() -> VZSerialPortConfiguration {
    VDebug("Creating console device.")
    let consoleConfiguration = VZVirtioConsoleDeviceSerialPortConfiguration()

    let inputFileHandle = FileHandle.standardInput
    let outputFileHandle = FileHandle.standardOutput

    // Put stdin into raw mode, disabling local echo, input canonicalization,
    // and CR-NL mapping.
    var attributes = termios()
    tcgetattr(inputFileHandle.fileDescriptor, &attributes)
    attributes.c_iflag &= ~tcflag_t(ICRNL)
    attributes.c_lflag &= ~tcflag_t(ICANON | ECHO)
    tcsetattr(inputFileHandle.fileDescriptor, TCSANOW, &attributes)

    let stdioAttachment = VZFileHandleSerialPortAttachment(fileHandleForReading: inputFileHandle,
                                                           fileHandleForWriting: outputFileHandle)

    consoleConfiguration.attachment = stdioAttachment
    return consoleConfiguration
}
