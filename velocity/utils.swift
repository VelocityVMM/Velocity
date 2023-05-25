//
//  utils.swift
//  velocity
//
//  Created by zimsneexh on 24.05.23.
//

import Foundation

public func createDirectorySafely(path: String) -> Bool {
    if(!FileManager.default.fileExists(atPath: path)) {
        do {
            try FileManager.default.createDirectory(atPath: path,                     withIntermediateDirectories: false)
        } catch {
            NSLog("Could not create directory: \(path)")
            return false;
        }
    }
    return true;
}
