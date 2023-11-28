//
//  main.swift
//  velocity
//
//  Created by zimsneexh on 24.05.23.
//  Copyright (c) zimsneexh 2023

import Foundation
import Virtualization
import AppKit

var VELOCITY_VERSION = 0.1
var VELOCITY_CODENAME = "Xen Catalyst"

public func main() {
    print("Velocity \(VELOCITY_VERSION) (\(VELOCITY_CODENAME)) - VMManager for Apple's Virtualization.framework")
    print("Copyright (c) 2023 zimsneexh (https://zsxh.eu)")
    print("")

    if ProcessInfo.processInfo.environment["TERM"] != nil {
        VLogEnableEscapeCodes = true
        VInfo("Running in Terminal, enabling escape sequences")
    } else {
        VInfo("Running in XCode, no escape codes")
    }

    VInfo("Starting up..")
    VelocityConfig.setup()

    if !VelocityConfig.check_directory() {
        VErr("Could not create all required directories.")
        return
    }

    let db = try! VDB("\(VelocityConfig.velocity_root)/db.sqlite");
    let efistore_manager = try! EFIStoreManager(efistore_dir: FilePath("\(VelocityConfig.velocity_root)/EFIStore"))
    let manager = try! VMManager(efistore_manager: efistore_manager, db: db)


    let api_queue = DispatchQueue(label: "VAPI")
    api_queue.async {
        let _ = try! VAPI(db: db, vm_manager: manager, port: 8090);
    }

    RunLoop.main.run()
}

main();
