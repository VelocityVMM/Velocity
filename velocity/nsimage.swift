//
//  nsimage.swift
//  velocity
//
//  Created by zimsneexh on 30.05.23.
//

import Foundation
import Virtualization

//
// Extension to NSImage to get as PNG,
// for use with Snapshot feature
//
extension NSImage {
    
    func pngWrite(to url: URL, options: Data.WritingOptions = .atomic) -> Bool {
        do {
            let data = self.pngData
            try data?.write(to: url, options: options)
            return true
        } catch {
            return false
        }
    }

    var pngData: Data? {
        guard let tiffRepresentation = tiffRepresentation, let bitmapImage = NSBitmapImageRep(data: tiffRepresentation) else { return nil }
        return bitmapImage.representation(using: .png, properties: [:])
    }
}

extension CGImage {
    // TODO: Optimize - With own compare (return immediately after first pixel mismatch)
    /// Compares this image to another and returns if they are the same
    /// - Parameter to: The image to compare this image to
    func is_equal(to: CGImage) -> Bool {
        // Compare dimensions
        if self.width != to.width || self.height != to.height {
            return false
        }

        guard let data_1 = self.dataProvider?.data else {
            VErr("Failed to get dataProvider.data of image 1");
            return false;
        }

        guard let data_2 = to.dataProvider?.data else {
            VErr("Failed to get dataProvider.data of image 2");
            return false;
        }

        return (data_1 as Data).withUnsafeBytes { rd_1 in
            (data_2 as Data).withUnsafeBytes { rd_2 in
                return memcmp(rd_1.baseAddress!, rd_2.baseAddress!, CFDataGetLength(data_1)) == 0;
            }
        }
    }
}
