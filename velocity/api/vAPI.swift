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

        // CORS headers
        let corsConfiguration = CORSMiddleware.Configuration(
            allowedOrigin: .all,
            allowedMethods: [.GET, .POST, .PUT, .OPTIONS, .DELETE, .PATCH],
            allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith, .userAgent, .accessControlAllowOrigin, "File-Name" ]
        )
        let cors = CORSMiddleware(configuration: corsConfiguration)
        self.app.middleware.use(cors, at: .beginning)

        defer { app.shutdown() }

        self.encoder = JSONEncoder()

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
}
