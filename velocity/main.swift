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

    let api_queue = DispatchQueue(label: "VAPI")
    api_queue.async {
        let _ = try! VAPI(db: db, port: 8090);
    }

    // Index local storage
    VInfo("Indexing local storage..")
    do {
        try Manager.index_iso_storage()
        try Manager.index_ipsw_storage()

        // Once IPSW models are fetched, we can continue starting up.
        VLog("Waiting for local IPSW model fetching..")
        MacOSFetcher.dispatch_group.wait();
        VLog("IPSW model fetching completed. Continuing")

        try Manager.index_storage()
    } catch {
        VErr("Could not index local storage: \(error)")
        return;
    }

    VInfo("Fetching available macOS installers from ipsw.me..")
    MacOSFetcher.fetch_list()

    // Start the RFB server
    VInfo("Starting RFB Server..")
    do {
        let rfb_server = try VRFBServer(port: UInt16(VelocityConfig.velocity_vnc_port));
        rfb_server.start();
    } catch let e {
        VErr("Failed to create RFB server: \(e)");
        return;
    }

    RunLoop.main.run()
}

main();
