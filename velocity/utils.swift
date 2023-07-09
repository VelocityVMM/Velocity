//
//  utils.swift
//  velocity
//
//  Created by zimsneexh on 24.05.23.
//

import Foundation
import Virtualization

class IPSWDownloader: NSObject, URLSessionDataDelegate {
    let url: URL
    let destination_url: URL
    var completed_target: URL
    var total_size: Float
    var fileHandle: FileHandle?
    var fetched_size = 0
    var operation_index: Int;

    init(url: URL, destination_url: URL, completed_target: URL, total_size: Float, operation_index: Int) {
        self.url = url
        self.destination_url = destination_url
        self.total_size = total_size
        self.completed_target = completed_target
        self.operation_index = operation_index
    }

    func start_download() {
        let sessionConfiguration = URLSessionConfiguration.default
        let session = URLSession(configuration: sessionConfiguration, delegate: self, delegateQueue: nil)
        let task = session.dataTask(with: url)
        task.resume()
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        do {
            FileManager.default.createFile(atPath: destination_url.path, contents: nil, attributes: nil)
            fileHandle = try FileHandle(forWritingTo: destination_url)
        } catch {
            VErr("Error creating file: \(error)")
            completionHandler(.cancel)
            return
        }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        self.fetched_size += data.count
        Manager.operations[self.operation_index].progress = Float(self.fetched_size) / Float(self.total_size)
        fileHandle?.write(data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            VErr("Download task completed with error: \(error)")
            Manager.operations[self.operation_index].description = "Downloading IPSW failed: \(error)";
        } else {
            VInfo("Download task completed successfully. Moving to ipsw cache..")
            Manager.operations[self.operation_index].description = "macOS download completed."
            do {
                try FileManager.default.moveItem(atPath: self.destination_url.absoluteString, toPath: self.completed_target.absoluteString)
            } catch {
                VErr("Could not move from DLCache to IPSW Storage..")
                Manager.operations[self.operation_index].description = "Could not move IPSW to Storage: \(error)";
            }
        }
        Manager.operations[self.operation_index].completed = true;
        fileHandle?.closeFile()
        VLog("Determining model for downloaded IPSW..")
        determine_for_ipsw(file: self.completed_target.absoluteString)
    }
}

//
// Information about the Host
//
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

/// System uptime
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

/// Available disk space on /
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

/// HW model name
func get_model_name() -> String {
    var size = 0
    sysctlbyname("hw.model", nil, &size, nil, 0)
    var model = [CChar](repeating: 0, count: size)
    sysctlbyname("hw.model", &model, &size, nil, 0)
    return String(cString: model)
}

/// CPU model name
func get_cpu_name() -> String {
    var size = 0
    sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
    var model = [CChar](repeating: 0, count: size)
    sysctlbyname("machdep.cpu.brand_string", &model, &size, nil, 0)
    return String(cString: model)
}

/// Create a directory safely
public func create_directory_safely(path: String) -> Bool {
    if(!FileManager.default.fileExists(atPath: path)) {
        do {
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: false)
        } catch {
            VErr("Could not create directory: \(path), \(error.localizedDescription)")
            return false;
        }
    }
    return true;
}
