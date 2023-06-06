//
//  manager.swift
//  velocity
//
//  Created by zimsneexh on 26.05.23.
//

import Foundation
import Virtualization

internal struct VelocityVMMError: Error, LocalizedError {
    let errorDescription: String?

    init(_ description: String) {
        errorDescription = description
    }
}


typealias availableVMList = [VMProperties]
typealias VMList = [VLVirtualMachine]

struct Manager {
    static var running_vms: VMList = [ ]
    static var available_vms: availableVMList = [ ]
    static var iso_images: [String] = [ ]
    
    //
    // Indexes the local storage on startup
    //
    static func index_storage(velocity_config: VelocityConfig) throws {
        do {
            let directory_content = try FileManager.default.contentsOfDirectory(atPath: velocity_config.velocity_bundle_dir.absoluteString)
            
            // Index VM Bundles
            for url in directory_content {
                let velocity_json = velocity_config.velocity_bundle_dir.appendingPathComponent(url).appendingPathComponent("Velocity.json").absoluteString
                
                if FileManager.default.fileExists(atPath: velocity_json) {
                    let decoder = JSONDecoder()
                    
                    var file_content: String;
                    do {
                        file_content = try String(contentsOfFile: velocity_json, encoding: .utf8)
                    } catch {
                        throw VelocityVMMError("Could not read VM definition: \(error)")
                    }
                    
                    let vm_info = try decoder.decode(VMProperties.self, from: Data(file_content.utf8))
                    VInfo("[Index] Found VM '\(vm_info.name)'.")
                    Manager.available_vms.append(vm_info)

                    if vm_info.autostart {
                        VInfo("Autostarting VM '\(vm_info.name)'");
                        let vm = try start_vm_by_name(velocity_config: velocity_config, vm_name: vm_info.name);
                        self.running_vms.append(vm);
                    }
                }
            }
            
            VLog("[Index] Indexing ISO Storage")
            
            // Index ISO image
            let iso_dir_content = try FileManager.default.contentsOfDirectory(atPath: velocity_config.velocity_iso_dir.absoluteString)
            
            for url in iso_dir_content {
                Manager.iso_images.append(url)
            }
        } catch {
            throw VelocityVMMError("Could not index local storage: \(error)")
        }
    }
    
    //
    // Deploys a new bundle, registers the VM as an available_vm
    //
    static func create_vm(velocity_config: VelocityConfig, vm_properties: VMProperties) throws {
        do {
            try deploy_vm(velocity_config: velocity_config, vm_properties: vm_properties)
            self.available_vms.append(vm_properties)
        } catch {
            throw VelocityVMMError("VZError: \(error.localizedDescription)")
        }
    }
    
    //
    // Starts a given virtual machine by
    // name
    //
    static func start_vm(velocity_config: VelocityConfig, name: String) throws {
        VInfo("VM start request received for \(name).")
        if let _ =  get_running_vm_by_name(name: name) {
            throw VelocityVMMError("VZError: VM is already running!")
        }
        
        // Run in background thread because of the NSWindow
        DispatchQueue.global().async {
            DispatchQueue.main.async {
                do {
                    let vm = try start_vm_by_name(velocity_config: velocity_config, vm_name: name)
                    Manager.running_vms.append(vm)
                } catch {
                    VErr("Could not start VirtualMachine: \(error)")
                }
            }
        }
    }
    
    //
    // Stop a VM by name
    //
    static func stop_vm(name: String) throws {
        VInfo("VM stop request received for \(name)")
        
        // Iterate with Index
        for (index, vm) in Manager.running_vms.enumerated() {
            if vm.vm_info.name == name {
                // check if VM can shut down.
                try DispatchQueue.main.sync {
                    if !vm.canRequestStop {
                        throw VelocityVMMError("Could not stop Virtual Machine.")
                    }
                }

                
                // Set VM State
                Manager.running_vms[index].vm_state = VMState.SHUTTING_DOWN

                // Dispatch VM Stop to MainThread
                DispatchQueue.main.sync {
                    vm.stop { (result) in
                        VLog("Virtual Machine stopped.")
                        Manager.running_vms.remove(at: index)
                    }
                }
                return
            }
        }
        throw VelocityVMMError("Cannot stop VM that is not running.")
    }
    
    static func remove_vm() {
        
    }
    
    //
    // Get running vm by its name
    //
    static func get_running_vm_by_name(name: String) -> VLVirtualMachine? {
        for vm in Manager.running_vms {
            if vm.vm_info.name == name {
                return vm;
            }
        }
        return nil;
    }

    //
    // Get available vm by its name
    //
    static func get_available_vm_by_name(name: String) -> VMProperties? {
        for vm in Manager.available_vms {
            if vm.name == name {
                return vm;
            }
        }
        return nil;
    }
    
    //
    // Take a snapshot from given VM
    //
    static func screen_snapshot(vm: VLVirtualMachine) -> Data? {
        let image = vm.window.cur_frame!;
        return NSImage(cgImage: image, size: .zero).pngData;
    }
    
    static func vnc_for_vm() {
        
    }
    
}
