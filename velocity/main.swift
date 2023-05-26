//
//  main.swift
//  velocity
//
//  Created by zimsneexh on 24.05.23.
//

import Foundation
import Virtualization
import AppKit

public struct VelocityConfig {
    
    var home_directory: String = NSHomeDirectory();
    var velocity_root: String;
    var velocity_bundle_dir: String;
    var velocity_iso_dir: String;
    
    //MARK: Add Velocity Port and BindAddr
    
    init() {
        //TODO: Is there a os.path.join like func in swift?
        self.velocity_root = self.home_directory + "/Velocity"
        self.velocity_bundle_dir = velocity_root + "/VMBundles"
        self.velocity_iso_dir = velocity_root + "/ISOs"
    }
    
    // Check if required directories exist
    // return false on error
    func check_directory() -> Bool {
        if(!createDirectorySafely(path: self.velocity_root)) {
            return false;
        }
        
        if(!createDirectorySafely(path: self.velocity_bundle_dir)) {
            return false;
        }
        
        if(!createDirectorySafely(path: self.velocity_iso_dir)) {
            return false;
        }
        
        return true;
    }
}



public func main() {
    NSLog("Velocity 0.1 -> Starting up..")
    NSLog("Checking directory structure..")
    
    let velocity_config = VelocityConfig();
    
    // check if required directories exist.
    if(!velocity_config.check_directory()) {
        fatalError("Could not setup required directories for Velocity.");
    }
    
    let vminfo = VMInfo(name: "TestVM", cpu_count: 2, memory_size: 4096, machine_type: MachineType.EFI_BOOTLOADER, iso_image_path: "/Users/zimsneexh/Downloads/Fedora-Workstation-Live-aarch64-38-1.6.iso", rosetta: true, disks: [ Disk(name: "main", size_mb: 4096) ])
    
    do {
        let _ = try new_vm(velocity_config: velocity_config, vm_info: vminfo)
    } catch {
        NSLog("Creation Error: \(error.localizedDescription)")
    }
    
    do {
        try start_vm_by_name(velocity_config: velocity_config, vm_name: "TestVM")
    } catch {
        NSLog("Could not start VirtualMachine: \(error.localizedDescription)")
    }
    
    return
}

main();
