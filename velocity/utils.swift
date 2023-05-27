//
//  utils.swift
//  velocity
//
//  Created by zimsneexh on 24.05.23.
//

import Foundation

struct HostInfo: Codable {
    
    var model_name: String
    var cpu_name: String
    var uptime: String
    var disk_info: String
    
    init() {
        self.model_name = get_model_name()
        self.cpu_name = get_cpu_name()
        self.uptime = "\(get_system_uptime()) hour(s)"
        self.disk_info = "\(get_available_disk_space())GB available."
    }
    
}

func get_system_uptime() -> Int {
    var boottime = timeval()
    var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]
    var size = MemoryLayout<timeval>.stride

    var now = time_t()
    var uptime: time_t = -1

    time(&now)
    if (sysctl(&mib, 2, &boottime, &size, nil, 0) != -1 && boottime.tv_sec != 0) {
        uptime = now - boottime.tv_sec
    }
    return uptime / 3600
}

func get_available_disk_space() -> Int {
    let path = NSTemporaryDirectory()
    let url = URL(fileURLWithPath: path)

    do {
        let resourceValues = try url.resourceValues(forKeys: [.volumeAvailableCapacityKey])
        if let availableCapacity = resourceValues.volumeAvailableCapacity {
            return Int(availableCapacity / 1024 / 1024 / 1024)
        }
    } catch {
        print("Failed to get disk space: \(error)")
        return 0
    }

    return 0
}


func get_model_name() -> String {
    var size = 0
    sysctlbyname("hw.model", nil, &size, nil, 0)
    var model = [CChar](repeating: 0, count: size)
    sysctlbyname("hw.model", &model, &size, nil, 0)
    return String(cString: model)
}

func get_cpu_name() -> String {
    var size = 0
    sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
    var model = [CChar](repeating: 0, count: size)
    sysctlbyname("machdep.cpu.brand_string", &model, &size, nil, 0)
    return String(cString: model)
}

public func create_directory_safely(path: String) -> Bool {
    if(!FileManager.default.fileExists(atPath: path)) {
        do {
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: false)
        } catch {
            NSLog("Could not create directory: \(path)")
            return false;
        }
    }
    return true;
}

