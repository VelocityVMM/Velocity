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
    static var velocity_http_port: Int = 8080
    static var velocity_vnc_port: Int = 1337

    // Parse command line arguments x=y into Key->Value pair
    static func setup() {
        // no args
        if CommandLine.arguments.count == 1 {
            return;
        }

        for argument in CommandLine.arguments {
            let split = argument.split(separator: "=")

            // Skip unknown arguments
            if split.count != 2 {
                continue;
            }

            let value = String(split[1])
            switch(String(split[0])) {

            case "-R":
                VLog("Setting VelocityRoot to \(value)")
                let user_path = URL(string: value)

                if user_path == nil {
                    VErr("Invalid VelocityRoot specified. Aborting.")
                    exit(1)
                }

                VelocityConfig.velocity_root = user_path!
                break

            // Port for HTTP
            case "-P":
                let port = Int(value)

                guard let port = port else {
                    VErr("Invalid integer specified for port.")
                    exit(1)
                }

                if port > 65535 || port <= 0 {
                    VErr("Invalid integer specified for port.")
                    exit(1)
                }

                VInfo("Setting VelocityHTTP Port to \(port)")
                VelocityConfig.velocity_http_port = port
                break

            // Port for VNC
            case "-V":
                let port = Int(value)

                guard let port = port else {
                    VErr("Invalid integer specified for port.")
                    exit(1)
                }

                if port > 65535 || port <= 0 {
                    VErr("Invalid integer specified for port.")
                    exit(1)
                }

                VInfo("Setting VelocityVNC Port to \(port)")
                VelocityConfig.velocity_vnc_port = port
                break

            // Help
            case "-H":
                break

            default:
                VWarn("Unrecognized commandline argument: \(argument)")
                break;
            }
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
