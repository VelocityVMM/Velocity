//
//  VirtualMachineManager
//  velocity
//
//  Created by zimsneexh on 24.05.23.
//

import Foundation
import Virtualization

enum MachineType: Codable {
    case MAC
    case EFI_BOOTLOADER
    case KERNEL_BOOT
}

internal struct VelocityVMMError: Error, LocalizedError {
    let errorDescription: String?

    init(_ description: String) {
        errorDescription = description
    }
}

public struct VMInfo: Codable {
    var name: String
    var cpu_count: Int
    var machine_type: MachineType
    var iso_image_path: String?
    var rosetta: Bool
    
    init(name: String, cpu_count: Int, machine_type: MachineType, iso_image_path: String, rosetta: Bool) {
        self.name = name
        self.cpu_count = cpu_count
        self.machine_type = machine_type
        self.iso_image_path = iso_image_path
        self.rosetta = rosetta
    }
    
    func as_json() throws  -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let data = try encoder.encode(self)
            return String(decoding: data, as: UTF8.self)
        } catch {
            throw VelocityVMMError("Could not decode as JSON")
        }
    }
    
    func validate() {
        //MARK: Todo..
        
        
    }
    
    func write(atPath: String) throws {
        do {
            try self.as_json().write(toFile: atPath, atomically: true, encoding: String.Encoding.utf8)
        } catch {
            throw VelocityVMMError(error.localizedDescription)
        }
    }
}

//
// Create a new virtual machine with
// given Struct
//
public func new_vm(velocity_config: VelocityConfig, vm_info: VMInfo) throws -> Bool {
    NSLog("Creating new virtual machine '\(vm_info.name)'..")
    let bundle_path = velocity_config.velocity_bundle_dir + "/\(vm_info.name).bundle/"
    
    // Check if already exists?
    if(FileManager.default.fileExists(atPath: bundle_path)) {
        throw VelocityVMMError("Could not create VM at path \(bundle_path), because a VM with this name already exists.")
    }
        
    // Create a VM Bundle
    NSLog("Creating Bundle at \(bundle_path)..")
    if(!createDirectorySafely(path: bundle_path)) {
        throw VelocityVMMError("Could not create bundle directory.")
    }
    
    // Write bundle json file to disk
    NSLog("Writing VM.json to disk..")
    do {
        try vm_info.write(atPath: bundle_path + "/Velocity.json")
    } catch {
        throw VelocityVMMError(error.localizedDescription)
    }
    
    // Create MachineIdentifier
    let machine_identifier_path = bundle_path + "MachineIdentifier"

    switch(vm_info.machine_type) {
    case MachineType.MAC:
        NSLog("TODO: unimplemented");
        return false;
        
    case MachineType.EFI_BOOTLOADER:
        if(!new_generic_machine_identifier(pathTo: machine_identifier_path)) {
            return false;
        }
        
        let efi_stor_path = bundle_path + "NVRAM"
        
        guard let _ = try? VZEFIVariableStore(creatingVariableStoreAt: URL(fileURLWithPath: efi_stor_path)) else {
            throw VelocityVMMError("Could not create EFI Variable storage in bundle.")
        }
        
    case MachineType.KERNEL_BOOT:
        if(!new_generic_machine_identifier(pathTo: machine_identifier_path)) {
            return false;
        }
    }
    
    
    
    
    
    
    
    return true;
}

public func create_vm() {
    /*
    if(vm_info.iso_image_path != nil) {
        NSLog("Attaching ISO image at path \(vm_info.iso_image_path!)..")
        
        guard let installer_disk_attachment = try? VZDiskImageStorageDeviceAttachment(url: URL(fileURLWithPath: vm_info.iso_image_path!), readOnly: true) else {
                throw VelocityVMMError("Could not attach ISO image to VM")
        }
    }
    */
}

internal func new_generic_machine_identifier(pathTo: String) -> Bool {
    NSLog("Creating VZGenericMachineIdentifier..")
    let machine_identifier = VZGenericMachineIdentifier()
    
    do {
        try machine_identifier.dataRepresentation.write(to: URL(fileURLWithPath: pathTo))
    } catch {
        NSLog("Could not write bundle file to disk.")
        return false;
    }
    return true;
}
