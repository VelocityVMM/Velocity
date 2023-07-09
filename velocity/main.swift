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

public struct VelocityConfig {
    
    var home_directory: URL = URL(string: NSHomeDirectory())!;
    var velocity_root: URL;
    var velocity_bundle_dir: URL;
    var velocity_iso_dir: URL;
    var velocity_ipsw_dir: URL;
    var velocity_dl_cache: URL;

    //MARK: Add Velocity Port and BindAddr
    
    init() {
        self.velocity_root = self.home_directory.appendingPathComponent("Velocity")
        //self.velocity_root = URL(string: "/Volumes/T7/Velocity/")!
        self.velocity_bundle_dir = self.velocity_root.appendingPathComponent("VMBundles")
        self.velocity_iso_dir = self.velocity_root.appendingPathComponent("ISOs")
        self.velocity_ipsw_dir = self.velocity_root.appendingPathComponent("IPSWs")
        self.velocity_dl_cache = self.velocity_root.appendingPathComponent("DLCache")
    }
    
    // Check if required directories exist
    // return false on error
    func check_directory() -> Bool {
        if(!create_directory_safely(path: self.velocity_root.absoluteString)) {
            return false;
        }
        
        if(!create_directory_safely(path: self.velocity_bundle_dir.absoluteString)) {
            return false;
        }
        
        if(!create_directory_safely(path: self.velocity_iso_dir.absoluteString)) {
            return false;
        }

        if(!create_directory_safely(path: self.velocity_ipsw_dir.absoluteString)) {
            return false;
        }

        if(!create_directory_safely(path: self.velocity_dl_cache.absoluteString)) {
            return false;
        }
        
        return true;
    }
}

public func main() {
    print("Velocity \(VELOCITY_VERSION) (\(VELOCITY_CODENAME)) - VMManager for Apple's Virtualization.framework")
    print("Copyright (c) 2023 zimsneexh (https://zsxh.eu)")
    print("")
    
    VInfo("Starting up..")
    VInfo("Checking directory structure..")
    let velocity_config = VelocityConfig();
    
    // check if required directories exist.
    if(!velocity_config.check_directory()) {
        fatalError("Could not setup required directories for Velocity.");
    }

    // Index local storage
    VInfo("Indexing local storage..")
    do {
        try Manager.index_iso_storage(velocity_config: velocity_config)
        try Manager.index_ipsw_storage(velocity_config: velocity_config)

        // Once IPSW models are fetched, we can continue starting up.
        VLog("Waiting for local IPSW model fetching..")
        MacOSFetcher.dispatch_group.wait();
        VLog("IPSW model fetching completed. Continuing")

        try Manager.index_storage(velocity_config: velocity_config)
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
