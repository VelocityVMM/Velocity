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

enum VMState: Codable {
    case RUNNING
    case STOPPED
}



public struct VirtualMachine: Codable {
    var vm_state: VMState
    var vm_info: VMInfo
    
    init(vm_state: VMState, vm_info: VMInfo) {
        self.vm_state = vm_state
        self.vm_info = vm_info
    }
}

// Non-Serializable VM Object for internal data
public struct VirtualMachineExt {
    var virtual_machine: VirtualMachine
    var vm_view: NSView
    var window_id: UInt32
    
    init(virtual_machine: VirtualMachine, vm_view: NSView, window_id: UInt32) {
        self.virtual_machine = virtual_machine
        self.vm_view = vm_view
        self.window_id = window_id
    }
}

typealias availableVMList = [VMInfo]
typealias VMList = [VirtualMachineExt]

struct Manager {
    static var running_vms: VMList = [ ]
    static var available_vms: availableVMList = [ ]
    
    //
    // Indexes the local storage on startup
    //
    static func index_storage(velocity_config: VelocityConfig) throws {
        do {
            let directory_content = try FileManager.default.contentsOfDirectory(atPath: velocity_config.velocity_bundle_dir.absoluteString)
            
            for url in directory_content {
                let velocity_json = velocity_config.velocity_bundle_dir.appendingPathComponent(url).appendingPathComponent("Velocity.json").absoluteString
                
                if FileManager.default.fileExists(atPath: velocity_json) {
                    let decoder = JSONDecoder()
                    
                    var file_content: String;
                    do {
                        file_content = try String(contentsOfFile: velocity_json, encoding: .utf8)
                    } catch {
                        throw VelocityVZError("Could not read VM definition: \(error)")
                    }
                    
                    let vm_info = try decoder.decode(VMInfo.self, from: Data(file_content.utf8))
                    NSLog("[Index] Found VM '\(vm_info.name)'.")
                    Manager.available_vms.append(vm_info)
                    
                }
            }
        } catch {
            throw VelocityVMMError("Could not index local storage: \(error)")
        }
    }
    
    //
    // Deploys a new bundle, registers the VM as an available_vm
    //
    static func create_vm(velocity_config: VelocityConfig, vm_info: VMInfo) throws {
        do {
            try deploy_vm(velocity_config: velocity_config, vm_info: vm_info)
            self.available_vms.append(vm_info)
        } catch {
            throw VelocityVMMError("VZError: \(error.localizedDescription)")
        }
    }
    
    //
    // Starts a given virtual machine by
    // name
    //
    static func start_vm(velocity_config: VelocityConfig, name: String) throws {
        NSLog("VM start request received.")
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
                    VLog("Could not start VirtualMachine.")
                }
            }
        }
    }
        
    static func stop_vm() {
        
    }
    
    static func remove_vm() {
        
    }
    
    //
    // Get running vm by its name
    //
    static func get_running_vm_by_name(name: String) -> VirtualMachineExt? {
        for vm in Manager.running_vms {
            if vm.virtual_machine.vm_info.name == name {
                return vm;
            }
        }
        return nil;
    }
    
    //
    // Take a snapshot from given VM
    //
    static func screen_snapshot(vm: VirtualMachineExt) -> Data? {
        DispatchQueue.main.sync {
            let image = capture_hidden_window(windowNumber: vm.window_id)
            return image?.pngData
        }
    }
    
    
    static func vnc_for_vm() {
        
    }
    
}
