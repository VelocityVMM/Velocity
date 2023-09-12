//
//  vAPI.swift
//  velocity
//
//  Created by Max Kofler on 27/07/23.
//

import Foundation
import Vapor

/// The Velocity api
class VAPI : Loggable {

    /// The logging context
    internal let context: String
    /// The Vapor instance
    let app: Application
    /// The database to run all queries on
    let db: VDB
    /// JSON encoder
    let encoder: JSONEncoder
    /// The currently registered authkeys. Can contain expired keys
    var authkeys: Dictionary<String, Authkey> = Dictionary()

    /// Starts the VAPI on the supplied port using the supplied database
    /// - Parameter db: The VDB connection to use for this api
    /// - Parameter port: The port the API should be available at
    /// - Parameter hostname: (optional) The hostname to use ("0.0.0.0")
    ///
    /// This immediately starts the API and blocks until the API errors or stops
    init(db: VDB, port: Int, hostname: String = "0.0.0.0") throws {
        self.context = "[vAPI (\(port))]"
        self.db = db;

        // Stupid workaround for Vapor
        // By default Vapor parses command line arguments and blows up
        // with "Operation could not be completed" with Velocitys arguments.
        let env = Environment(name: "vapi-development", arguments: ["vapor"])

        self.app = Application(env)
        self.encoder = JSONEncoder()

        self.app.logger.logLevel = .critical

        // CORS headers
        let corsConfiguration = CORSMiddleware.Configuration(
            allowedOrigin: .all,
            allowedMethods: [.GET, .POST, .PUT, .OPTIONS, .DELETE, .PATCH],
            allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith, .userAgent, .accessControlAllowOrigin, "File-Name" ]
        )
        let cors = CORSMiddleware(configuration: corsConfiguration)
        self.app.middleware.use(cors, at: .beginning)

        defer { app.shutdown() }

        if env.isRelease {
            VInfo("vAPI is starting up in RELEASE mode")
        } else {
            VInfo("vAPI is starting up in DEBUG mode")
        }

        try self.register_endpoints_u(route: self.app.grouped("u"))

        // Setup server properties
        app.http.server.configuration.hostname = hostname
        app.http.server.configuration.port = port

        VInfo("Starting VAPI on port \(port)...")
        do {
            try self.app.run()
        } catch {
            self.VErr("Failed to start vAPI: \(error.localizedDescription)")
            throw VelocityWebError("\(error.localizedDescription)")
        }
    }

    /// Groups the request and response structures for every API endpoint
    internal struct Structs {

    }

    /// A key that identifies a user and has a certain validity timeframe
    struct Authkey {
        /// The lifetime of an authkey in seconds
        static var key_lifetime: UInt64 = 60

        /// The `user` this key authenticates
        let user: VDB.User
        /// The key UUID
        let key: UUID
        /// The timestamp the key has been created
        let creation_date: Date

        /// Generates a new authkey identifying the supplied user
        /// - Parameter user: The user to authenticate
        init(user: VDB.User) {
            self.user = user
            self.key = UUID()
            self.creation_date = Date.now
        }

        /// The date this key will expire
        func expiration_date() -> Date {
            return self.creation_date.addingTimeInterval(Double(Authkey.key_lifetime))
        }

        /// The date this key will expire in unix seconds
        func expiration_datetime() -> UInt64 {
            return UInt64(self.expiration_date().timeIntervalSince1970)
        }

        /// Check if the key is already expired
        /// - Parameter date: (optional) A specific date to use, else use the current from `Date.now`
        func is_expired(date: Date? = nil) -> Bool {
            guard let date = date else {
                return self.expiration_date() <= Date.now
            }
            return self.expiration_date() <= date
        }

        /// Provide some information about the authkey
        func info() -> String {
            return "Authkey (\(self.key.uuidString), valid until: \(self.expiration_date().description(with: .current)))"
        }
    }

    /// Generates a new authkey identifying the user and stores in this API instance
    /// - Parameter user: The user to associate with this authkey
    func generate_authkey(user: VDB.User) -> Authkey {
        let key = Authkey(user: user)

        self.authkeys[key.key.uuidString] = key

        VTrace("New authkey for \(user.info()): \(key.key.uuidString), valid until: \(key.expiration_date()), \(self.authkeys.count) active keys")

        return key
    }

    /// Searches for an authkey and checks if it isn't expired
    /// - Parameter authkey: The authkey's uuid string handed out to the client
    /// - Parameter date: (optional) A specific date to use, else use the current from `Date.now`
    /// - Returns: The authkey if it is still valid, else `nil`
    func get_authkey(authkey: String, date: Date? = nil) -> Authkey? {
        // Search for the key
        guard let key = self.authkeys[authkey] else {
            return nil
        }

        if (key.is_expired(date: date)) {
            // If the key is expired, remove it from the active keys
            self.authkeys.removeValue(forKey: authkey)
            return nil
        }

        return key
    }

    /// All the available permissions for this api
    static let available_permissions: [VDB.PermissionTemplate] = [
        // velocity.user
        VDB.PermissionTemplate("velocity.user.create", "Create new users"),
        VDB.PermissionTemplate("velocity.user.remove", "Remove users that are in the group from the system"),
        VDB.PermissionTemplate("velocity.user.assign", "Assign new users to the group"),
        VDB.PermissionTemplate("velocity.user.revoke", "Remove users from the group"),
        VDB.PermissionTemplate("velocity.user.view", "View user permissions"),
        VDB.PermissionTemplate("velocity.user.list", "List available users"),


        // velocity.group
        VDB.PermissionTemplate("velocity.group.create", "Create a new subgroup to the group"),
        VDB.PermissionTemplate("velocity.group.remove", "Remove a subgroup"),
        VDB.PermissionTemplate("velocity.group.view", "View group information"),

        // velocity.vm
        VDB.PermissionTemplate("velocity.vm.create", "Create a new virtual machine in the group"),
        VDB.PermissionTemplate("velocity.vm.remove", "Remove a virtual machine from the group"),
        VDB.PermissionTemplate("velocity.vm.alter", "Alter a virtual machine parameters (CPU, RAM...)"),
        VDB.PermissionTemplate("velocity.vm.view", "View statistics for a virtual machine"),
        VDB.PermissionTemplate("velocity.vm.interact", "Interact with a virtual machine (RFB, Serial...)"),
        VDB.PermissionTemplate("velocity.vm.state", "Alter the virtual machine state (start, stop, pause...)"),
    ]
}
