//
//  vMacOSFetching.swift
//  velocity
//
//  Created by zimsneexh on 12.06.23.
//

import Foundation
import Virtualization

class MacOSFetcher {

    public static var Firmwares: [Firmware]? = [ ]
    public static var dispatch_group: DispatchGroup = DispatchGroup();

    // Fetches a list of available macOS installers
    static func fetch_list() {

        // IPSWs seem to be UniversalMac (virtualization Kernel included),
        // so choosing any ARM mac Firmware should be fine.
        let url = URL(string: "https://api.ipsw.me/v4/device/MacBookPro17,1")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let session = URLSession.shared

        let task = session.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                VErr("Could not fetch macOS Installer Index: \(String(describing: error))")
                return
            }

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                do {
                    let decoder = JSONDecoder()
                    MacOSFetcher.Firmwares = try decoder.decode(FirmwareResponse.self, from: data).firmwares
                    VInfo("\(MacOSFetcher.Firmwares!.count) .ipsw installer images available for download.")
                } catch let jsonError {
                    VErr("Error parsing JSON: \(jsonError)")
                }
            } else {
                VErr("Request failed with status code: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            }
        }
        task.resume()
    }

    // Downloads an Installer with given buildid
    static func download_installer(vc: VelocityConfig, buildid: String) -> Bool {
        guard let firmwares = MacOSFetcher.Firmwares else {
            return false;
        }

        var firmware_to_dl: Firmware?;

        for firmware in firmwares {
            if firmware.buildid == buildid {
                firmware_to_dl = firmware
                break
            }
        }

        guard let firmware_to_dl = firmware_to_dl else {
            return false;
        }

        DispatchQueue.global().async {
            let file_url = URL(string: firmware_to_dl.url)!

            let file_name = file_url.lastPathComponent

            let destination = vc.velocity_dl_cache.appendingPathComponent(file_name)
            let completed_target = vc.velocity_ipsw_dir.appendingPathComponent(file_name)


            let dl_op = vOperation(name: "Downloading macOS installer..", description: "Downloading requested macOS installer: \(file_name). This will take some time.", progress: 0)
            Manager.operations.append(dl_op)

            let index = Manager.operations.count - 1

            let downloader = IPSWDownloader(vc: vc, url: file_url, destination_url: destination, completed_target: completed_target, total_size: Float(firmware_to_dl.filesize), operation_index: index)
            downloader.start_download()
        }
        return true;
    }
}

public func determine_for_ipsw(velocity_config: VelocityConfig, file: String) {
    MacOSFetcher.dispatch_group.enter();
    let file_url = URL(fileURLWithPath: velocity_config.velocity_ipsw_dir.appendingPathComponent(file).absoluteString)

    VLog("Loading IPSW: \(file)")
    VZMacOSRestoreImage.load(from: file_url, completionHandler: { (result: Result<VZMacOSRestoreImage, Error>) in
        switch result {
        case let .failure(error):
            VErr("Could not load IPSW: \(error.localizedDescription)")
            MacOSFetcher.dispatch_group.leave();

        case let .success(restore_image):
            VLog("IPSW file loaded.")

            guard let macos_config = restore_image.mostFeaturefulSupportedConfiguration else {
                VErr("No supported configuration available.")
                return
            }

            if !macos_config.hardwareModel.isSupported {
                VErr("Requested configuration isn't supported on the current host.")
                return
            }

            VLog("Determined available macOS config for IPSW: \(file)")
            Manager.ipsw_hardwaremodel[file] = macos_config.hardwareModel
            MacOSFetcher.dispatch_group.leave();
        }
    })
}

struct Firmware: Codable {
    var identifier: String;
    var version: String;
    var buildid: String;
    var sha1sum: String;
    var md5sum: String;
    var filesize: Int;
    var url: String;
    var releasedate: String;
    var uploaddate: String;
    var signed: Bool;
}

struct FirmwareResponse: Codable {
    var name: String;
    var identifier: String;
    var firmwares: [Firmware];
}
