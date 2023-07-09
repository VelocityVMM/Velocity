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

struct vOperation: Codable {
    var name: String;
    var description: String;
    var progress: Float;
    var completed: Bool;

    init(name: String, description: String, progress: Float) {
        self.name = name
        self.description = description
        self.progress = progress
        self.completed = false
    }
}

struct Manager {
    static var virtual_machines: [vVirtualMachine] = [ ]
    static var iso_images: [String] = [ ]
    static var ipsws: [String] = [ ]
    static var ipsw_hardwaremodel: [String: VZMacHardwareModel] = [:]
    static var operations: [vOperation] = [ ]

    /// Indexes the ISO image storage
    static func index_iso_storage(velocity_config: VelocityConfig) throws {
        Manager.iso_images = [ ]
        VInfo("[Index] Indexing ISO Storage")

        // Index ISO image
        let iso_dir_content = try FileManager.default.contentsOfDirectory(atPath: velocity_config.velocity_iso_dir.absoluteString)

        for url in iso_dir_content {
            VTrace("Adding ISO: \(url)")
            Manager.iso_images.append(url)
        }
    }

    /// Indexes the IPSW storage
    static func index_ipsw_storage(velocity_config: VelocityConfig) throws {
        Manager.ipsws = [ ]
        VInfo("[Index] Indexing IPSW Storage")

        // Index ISO image
        let ipsw_content = try FileManager.default.contentsOfDirectory(atPath: velocity_config.velocity_ipsw_dir.absoluteString)

        for url in ipsw_content {
            VTrace("Adding IPSW: \(url)")
            Manager.ipsws.append(url)
            VTrace("Fetching hardwareModel for \(url)")
            determine_for_ipsw(velocity_config: velocity_config, file: url)
        }
    }

    /// Indexes the local VM storage on startup
    /// and starts autostart VMs
    static func index_storage(velocity_config: VelocityConfig) throws {
        self.iso_images = [ ]
        self.virtual_machines = [ ]

        VInfo("[Index] Indexing local bundles..")
        let directory_content = try FileManager.default.contentsOfDirectory(atPath: velocity_config.velocity_bundle_dir.absoluteString)
        
        for bundle_path in directory_content {

            // Check if the directory contains a vVM file
            let vm_path = velocity_config.velocity_bundle_dir.appendingPathComponent( bundle_path).appendingPathComponent("vVM.json")

            if FileManager.default.fileExists(atPath: vm_path.absoluteString) {

                do {
                    guard let vm = try vVirtualMachine.from_storage_format(vc: velocity_config, storage_format: try vVMStorageFormat.from_file(path: vm_path.absoluteString)) else {
                        throw VelocityVMMError("No such VirtualMachine.")
                    }

                    VLog("Found VM: '\(vm.name)'")

                    if vm.autostart {
                        // Check if the macOS virtual machine is installed
                        // before attempting to autostart it
                        if let mac_specific = vm.specific.0 {
                            if mac_specific.installed {
                                vm.start()
                            }
                        }

                        // Autostart EFI machines directly, no install needed.
                        if let _ = vm.specific.1 {
                            vm.start()
                        }
                    }

                    self.virtual_machines.append(vm)
                } catch {
                    throw VelocityVMMError(error.localizedDescription)
                }


            }
        }
    }

    /// Get a VirtualMachine by name
    /// Parameter: name of the virtual machine
    static func get_vm_by_name(name: String) -> vVirtualMachine? {
        for vm in Manager.virtual_machines {
            if vm.name == name {
                return vm;
            }
        }

        return nil;
    }
}
