//
//  Simple Interface to Virtualization.framework
//  velocity
//
//  Created by zimsneexh on 24.05.23.
//

import Foundation
import Virtualization

struct VelocityVZError: Error, LocalizedError {
    let errorDescription: String?

    init(_ description: String) {
        errorDescription = description
    }
}

internal func create_disk_image(pathTo: String, disk: vDisk) throws {
    let disk_path = pathTo + "/\(disk.name).img"
    
    //MARK: check if disk name is valid.
    
    if !FileManager.default.createFile(atPath: disk_path, contents: nil, attributes: nil) {
        throw VelocityVZError("Could not write disk image to file.")
    }
    
    guard let main_disk = try? FileHandle(forWritingTo: URL(fileURLWithPath: disk_path)) else {
        throw VelocityVZError("Could not open the disk image for writing.")
    }

    do {
        try main_disk.truncate(atOffset: disk.size_mb * 1024 * 1024)
        VInfo("Disk image created at \(disk_path).")
    } catch {
        throw VelocityVZError("Could not truncate disk image '\(disk.name)'.")
    }
}

internal func new_generic_machine_identifier(pathTo: String) -> Bool {
    VDebug("Creating VZGenericMachineIdentifier..")
    let machine_identifier = VZGenericMachineIdentifier()
    
    do {
        try machine_identifier.dataRepresentation.write(to: URL(fileURLWithPath: pathTo))
    } catch {
        VErr("Could not write machine identifier to disk.")
        return false;
    }
    return true;
}
