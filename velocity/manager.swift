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


typealias availableVMList = [Any]

struct Manager {
    static var virtual_machines: [vVirtualMachine] = [ ]
    static var iso_images: [String] = [ ]

    //
    // Indexes the ISO image storage
    //
    static func index_iso_storage(velocity_config: VelocityConfig) throws {
        VLog("[Index] Indexing ISO Storage")

        // Index ISO image
        let iso_dir_content = try FileManager.default.contentsOfDirectory(atPath: velocity_config.velocity_iso_dir.absoluteString)

        for url in iso_dir_content {
            Manager.iso_images.append(url)
        }
    }

    /// Indexes the local VM storage on startup
    /// and starts autostart VMs
    static func index_storage(velocity_config: VelocityConfig) throws {
        self.iso_images = [ ]
        self.virtual_machines = [ ]

        VInfo("Indexing local bundles..")
        let directory_content = try FileManager.default.contentsOfDirectory(atPath: velocity_config.velocity_bundle_dir.absoluteString)
        
        for bundle_path in directory_content {

            // Check if the directory contains a vVM file
            let vm_path = velocity_config.velocity_bundle_dir.appendingPathComponent( bundle_path).appendingPathComponent("vVM.json")

            if FileManager.default.fileExists(atPath: vm_path.absoluteString) {
                let vm = vVirtualMachine.from_storage_format(vc: velocity_config, storage_format: try vVMStorageFormat.from_file(path: vm_path.absoluteString))

                if let vm {
                    VLog("Found VM: '\(vm.name)'")

                    if vm.autostart {
                        vm.start()
                    }

                    self.virtual_machines.append(vm)
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
