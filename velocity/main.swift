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
    
    VInfo("Starting up..")
    VelocityConfig.setup()

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

    // Need to dispatch webserver as a background thread, because
    // the UI needs the main thread to render
    VLog("Starting webserver..")
    DispatchQueue.global().async {
        do {
            try start_web_server(velocity_config: velocity_config)
        } catch {
            fatalError("Could not start webserver: \(error.localizedDescription)")
        }
    }

    // Start the RFB server
    do {
        let rfb_server = try VRFBServer(port: 1337);
        rfb_server.start();
    } catch let e {
        VErr("Failed to create RFB server: \(e)");
        return;
    }


    RunLoop.main.run(until: Date.distantFuture)
}

main();
