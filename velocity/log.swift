//
//  log.swift
//  velocity
//
//  Created by zimsneexh on 27.05.23.
//

import Foundation

/// The loglevels for logging
enum Loglevel: Int {
    case Err
    case Warn
    case Info
    case Debug
    case Trace
}

/// The current loglevel to use
var VLoglevel: Loglevel = Loglevel.Info;

/// Log the specified message to the log
/// - Parameter message: The message to print
/// - Parameter level: The loglevel to use (optional) if `nil`, this will always print
func VLog(_ message: String, level: Loglevel? = nil) {
    if let level = level {
        //Early return if the loglevel is too low
        if VLoglevel.rawValue < level.rawValue {
            return;
        }

        var c = "I";

        switch level {
        case Loglevel.Err: c = "E"
        case Loglevel.Warn: c = "W"
        case Loglevel.Info: c = "I"
        case Loglevel.Debug: c = "D"
        case Loglevel.Trace: c = "T"
        }

        NSLog("[Velocity][\(c)] \(message)");
    } else {
        NSLog("[Velocity] \(message)");
    }
}

/// Log the specified message under the `Err` loglevel
/// - Parameter message: The message to print
func VErr(_ message: String) {
    VLog(message, level: Loglevel.Err);
}

/// Log the specified message under the `Warn` loglevel
/// - Parameter message: The message to print
func VWarn(_ message: String) {
    VLog(message, level: Loglevel.Warn);
}

/// Log the specified message under the `Info` loglevel
/// - Parameter message: The message to print
func VInfo(_ message: String) {
    VLog(message, level: Loglevel.Info);
}

/// Log the specified message under the `Debug` loglevel
/// - Parameter message: The message to print
func VDebug(_ message: String) {
    VLog(message, level: Loglevel.Debug);
}

/// Log the specified message under the `Trace` loglevel
/// - Parameter message: The message to print
func VTrace(_ message: String) {
    VLog(message, level: Loglevel.Trace);
}
