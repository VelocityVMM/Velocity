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
            try! data?.write(to: url, options: options)
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
