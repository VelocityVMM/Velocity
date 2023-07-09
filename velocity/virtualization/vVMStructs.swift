//
//  vVMStructs.swift
//  velocity
//
//  Created by zimsneexh on 10.06.23.
//

import Foundation
import Virtualization

/// VirtualMachineState
enum vVMState: Codable {
    case RUNNING
    case STOPPED
    case SHUTTING_DOWN
    case CRASHED
    case ABORTED
}

/// Virtual Disk Image.
internal struct vDisk: Codable {
    var name: String
    var size_mb: UInt64

    init(name: String, size_mb: UInt64) {
        self.name = name
        self.size_mb = size_mb
    }
}

struct vVMStorageFormat: Codable {
    var name: String;
    var cpu_count: UInt;
    var memory_size: UInt;
    var screen_size: NSSize;
    var autostart: Bool;
    var disks: [vDisk];

    var mac_specific: vMacOptions? = nil;
    var efi_specific: vEFIOptions? = nil;

    init(name: String, cpu_count: UInt, memory_size: UInt, screen_size: NSSize, autostart: Bool, disks: [vDisk], specific: (vMacOptions?, vEFIOptions?)) {
        self.name = name
        self.cpu_count = cpu_count
        self.memory_size = memory_size
        self.screen_size = screen_size
        self.autostart = autostart
        self.disks = disks

        if let mac_specific = specific.0 {
            self.mac_specific = mac_specific;
        }

        if let efi_specific = specific.1 {
            self.efi_specific = efi_specific;
        }
    }

    static func from_file(path: String) throws -> vVMStorageFormat {
        let decoder = JSONDecoder()
        var file_content: String;
        do {
            file_content = try String(contentsOfFile: path, encoding: .utf8)
        } catch {
            throw VelocityVZError("Could not read VM definition: \(error)")
        }

        let vVMStorageFormat = try decoder.decode(vVMStorageFormat.self, from: Data(file_content.utf8))
        return vVMStorageFormat;
    }

    func as_json() throws  -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        do {
            let data = try encoder.encode(self)
            return String(decoding: data, as: UTF8.self)
        } catch {
            throw VelocityVZError("Could not decode as JSON")
        }
    }

    func write(atPath: String) throws {
        do {
            try self.as_json().write(toFile: atPath, atomically: true, encoding: String.Encoding.utf8)
        } catch {
            throw VelocityVZError(error.localizedDescription)
        }
    }
}

/// vVirtualMachine object as a Codable struct.
struct vVMInfo: Codable {
    var name: String;
    var cpu_count: UInt;
    var memory_size: UInt;
    var screen_size: NSSize;
    var autostart: Bool;
    var disks: [vDisk];
    var state: vVMState;

    var mac_specific: vMacOptions? = nil;
    var efi_specific: vEFIOptions? = nil;

    init(name: String, cpu_count: UInt, memory_size: UInt, screen_size: NSSize, autostart: Bool, disks: [vDisk], state: vVMState, specific: (vMacOptions?, vEFIOptions?)) {
        self.name = name
        self.cpu_count = cpu_count
        self.memory_size = memory_size
        self.screen_size = screen_size
        self.autostart = autostart
        self.disks = disks
        self.state = state

        if let mac_specific = specific.0 {
            self.mac_specific = mac_specific;
        }

        if let efi_specific = specific.1 {
            self.efi_specific = efi_specific;
        }
    }

    func as_json() throws  -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        do {
            let data = try encoder.encode(self)
            return String(decoding: data, as: UTF8.self)
        } catch {
            throw VelocityVZError("Could not decode as JSON")
        }
    }

    func write(atPath: String) throws {
        do {
            try self.as_json().write(toFile: atPath, atomically: true, encoding: String.Encoding.utf8)
        } catch {
            throw VelocityVZError(error.localizedDescription)
        }
    }
}

struct vMacOptions: Codable {
    var ipsw_path: String;
    var installed: Bool;

    func as_json() throws  -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        do {
            let data = try encoder.encode(self)
            return String(decoding: data, as: UTF8.self)
        } catch {
            throw VelocityVZError("Could not decode as JSON")
        }
    }

    func write(atPath: String) throws {
        do {
            try self.as_json().write(toFile: atPath, atomically: true, encoding: String.Encoding.utf8)
        } catch {
            throw VelocityVZError(error.localizedDescription)
        }
    }
}

struct vEFIOptions: Codable {
    var enable_rosetta: Bool;
    var iso_path: String;

    init(enable_rosetta: Bool, iso_path: String) {
        self.enable_rosetta = enable_rosetta
        self.iso_path = iso_path
    }

    func as_json() throws  -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        do {
            let data = try encoder.encode(self)
            return String(decoding: data, as: UTF8.self)
        } catch {
            throw VelocityVZError("Could not decode as JSON")
        }
    }

    func write(atPath: String) throws {
        do {
            try self.as_json().write(toFile: atPath, atomically: true, encoding: String.Encoding.utf8)
        } catch {
            throw VelocityVZError(error.localizedDescription)
        }
    }
}
