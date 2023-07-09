//
//  config.swift
//  velocity
//
//  Created by zimsneexh on 09.07.23.
//

import Foundation


public struct VelocityConfig {

    static var velocity_root: URL = URL(string: NSHomeDirectory())!.appendingPathComponent("Velocity/")
    static var velocity_bundle_dir: URL {
        get {
            return velocity_root.appendingPathComponent("VMBundles")
        }
    }
    static var velocity_iso_dir: URL {
        get {
            return velocity_root.appendingPathComponent("ISOs")
        }
    }
    static var velocity_ipsw_dir: URL {
        get {
            return velocity_root.appendingPathComponent("IPSWs")
        }
    }
    static var velocity_dl_cache: URL {
        get {
            return velocity_root.appendingPathComponent("DLCache")
        }
    }

    //static var velocity_http_port: Int;
    //static var velocity_vnc_port: Int;

    // Parse command line arguments x=y into Key->Value pair
    static func setup() {
        for argument in CommandLine.arguments {
            let split = argument.split(separator: "=")

            // Skip unknown arguments
            if split.count != 2 {
                VWarn("Unrecognized commandline argument: \(argument)")
                continue;
            }

            let value = String(split[1])
            switch(String(split[0])) {

            case "-R":
                VLog("Setting VelocityRoot to \(value)")
                VelocityConfig.velocity_root = URL(filePath: value)
                break

            // Port for HTTP
            case "-P":
                break

            // Port for VNC
            case "-V":
                break

            // Help
            case "-H":
                break

            default:
                VWarn("Unrecognized commandline argument: \(argument)")
                break;
            }
        }

        if !check_directory() {
            VErr("Could not setup required Velocity directories. Cannot continue.")
            exit(-1)
        }
    }

    /// Check if required directories exist
    /// return false on error
    static func check_directory() -> Bool {
        if(!create_directory_safely(path: VelocityConfig.velocity_root.absoluteString)) {
            return false;
        }

        if(!create_directory_safely(path: VelocityConfig.velocity_bundle_dir.absoluteString)) {
            return false;
        }

        if(!create_directory_safely(path: VelocityConfig.velocity_iso_dir.absoluteString)) {
            return false;
        }

        if(!create_directory_safely(path: VelocityConfig.velocity_ipsw_dir.absoluteString)) {
            return false;
        }

        if(!create_directory_safely(path: VelocityConfig.velocity_dl_cache.absoluteString)) {
            return false;
        }

        return true;
    }
}
