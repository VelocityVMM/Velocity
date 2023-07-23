//
//  vDB.swift
//  velocity
//
//  Created by Max Kofler on 21/07/23.
//

import Foundation
import SQLite

/// The Velocity database class
class VDB : Loggable {
    let context: String;
    /// The database connection to work with
    let db: Connection;

    /// Opens a new database connection at the specified location
    /// - Parameter location: The location to open the database at
    convenience init(_ location: Connection.Location = Connection.Location.inMemory) throws {
        try self.init(db: try Connection(location), context: "[vDB \(location)]");
    }

    /// Opens a new database connection at the specified location
    /// - Parameter location: The location to the database in the filesystem
    convenience init(_ location: String) throws {
        try self.init(db: try Connection(location), context: "[vDB \(location)]");
    }

    /// Initializes the internal database connection to a well-known state
    internal init(db: Connection, context: String) throws {
        self.context = context;
        self.db = db;
    }
}
