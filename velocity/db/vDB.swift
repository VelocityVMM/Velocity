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

    /// The available mediapools
    var mediapools: Dictionary<Int64, MediaPool> = Dictionary()

    /// The available host NICs
    var host_nics: Dictionary<NICID, HostNIC> = Dictionary()

    /// The `users` table
    let t_users: Users;
    /// The `groups` table
    let t_groups: Groups
    /// The `permissions` table
    let t_permissions: Permissions
    /// The `memberships` table
    let t_memberships: Memberships
    /// The `media` table
    let t_media: TMedia
    /// The `grouppools` table
    let t_grouppools: TGroupPools

    /// Opens a new database connection at the specified location
    /// - Parameter location: The location to open the database at
    convenience init(_ location: Connection.Location = Connection.Location.inMemory) throws {
        try self.init(db: try Connection(location), context: "[vDB]");
    }

    /// Opens a new database connection at the specified location
    /// - Parameter location: The location to the database in the filesystem
    convenience init(_ location: String) throws {
        try self.init(db: try Connection(location), context: "[vDB]");
    }

    /// Initializes the internal database connection to a well-known state
    internal init(db: Connection, context: String) throws {
        self.context = context;
        self.db = db;
        self.t_users = try Users(db: self.db);
        self.t_groups = try Groups(db: self.db)
        self.t_permissions = try Permissions(db: self.db)
        self.t_memberships = try Memberships(db: self.db, groups: self.t_groups, users: self.t_users, permissions: self.t_permissions)
        self.t_media = try TMedia(db: self.db, groups: self.t_groups)
        self.t_grouppools = try TGroupPools(db: self.db, t_groups: self.t_groups)

        try self.db.execute("PRAGMA foreign_keys = ON;");
    }
}

extension Connection {
    /// Queries the database if the count of the query is not `0`
    /// - Parameter table: The table to search in
    /// - Parameter predicate: The predicate to use for searching
    func exists(_ table: Table, _ predicate: Expression<Bool>) throws -> Bool {
        try self.scalar(table.filter(predicate).count) > 0;
    }
}
