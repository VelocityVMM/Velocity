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

/// A protocol to have a context that allows for the V* logging functions to be called on the object
/// and provide context when logging
protocol Loggable {
    var context: String { get };
}

extension Loggable {
    /// Log the specified message under the `Err` loglevel using the context of this class
    /// - Parameter message: The message to print
    func VErr(_ message: String) {
        velocity.VErr(message, self.context);
    }

    /// Log the specified message under the `Err` loglevel using the context of this class
    /// - Parameter message: The message to print
    func VWarn(_ message: String) {
        velocity.VWarn(message, self.context);
    }

    /// Log the specified message under the `Err` loglevel using the context of this class
    /// - Parameter message: The message to print
    func VInfo(_ message: String) {
        velocity.VInfo(message, self.context);
    }

    /// Log the specified message under the `Err` loglevel using the context of this class
    /// - Parameter message: The message to print
    func VDebug(_ message: String) {
        velocity.VDebug(message, self.context);
    }

    /// Log the specified message under the `Err` loglevel using the context of this class
    /// - Parameter message: The message to print
    func VTrace(_ message: String) {
        velocity.VTrace(message, self.context);
    }
}

/// The current loglevel to use
var VLoglevel: Loglevel = Loglevel.Debug;

/// If the logging should use colors and escape codes
var VLogEnableEscapeCodes: Bool = false

/// Log the specified message to the log
/// - Parameter message: The message to print
/// - Parameter context: The context to print for the message (optional)
/// - Parameter level: The loglevel to use (optional) if `nil`, this will always print
func VLog(_ message: String, _ context: String? = nil, level: Loglevel? = nil) {
    var prefix = "[Velocity]"

    if VLogEnableEscapeCodes {
        prefix = "\u{001B}[96m[Velocity]"
    }

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

        prefix += "[\(c)]"
    } else {
        prefix += "[_]"
    }

    if let context = context {
        prefix += context;
    }

    if VLogEnableEscapeCodes {
        prefix += "\u{001B}[0m"
    }

    NSLog("\(prefix) \(message)")
}

/// Log the specified message under the `Err` loglevel
/// - Parameter message: The message to print
/// - Parameter context: The context to print for the message (optional)
func VErr(_ message: String, _ context: String? = nil) {
    VLog(message, context, level: Loglevel.Err);
}

/// Log the specified message under the `Warn` loglevel
/// - Parameter message: The message to print
/// - Parameter context: The context to print for the message (optional)
func VWarn(_ message: String, _ context: String? = nil) {
    VLog(message, context, level: Loglevel.Warn);
}

/// Log the specified message under the `Info` loglevel
/// - Parameter message: The message to print
/// - Parameter context: The context to print for the message (optional)
func VInfo(_ message: String, _ context: String? = nil) {
    VLog(message, context, level: Loglevel.Info);
}

/// Log the specified message under the `Debug` loglevel
/// - Parameter message: The message to print
/// - Parameter context: The context to print for the message (optional)
func VDebug(_ message: String, _ context: String? = nil) {
    VLog(message, context, level: Loglevel.Debug);
}

/// Log the specified message under the `Trace` loglevel
/// - Parameter message: The message to print
/// - Parameter context: The context to print for the message (optional)
func VTrace(_ message: String, _ context: String? = nil) {
    VLog(message, context, level: Loglevel.Trace);
}
