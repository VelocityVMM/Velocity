//
// MIT License
//
// Copyright (c) 2023 The Velocity contributors
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//

import Foundation
import System
import SQLite

/// The media pool id (`MPID`) is an `Int64`
typealias MPID = Int64

extension VDB {
    /// A media pool, defined by the administrator
    class MediaPool : Loggable {
        /// The logging context
        internal let context: String

        /// The public, friendly name for this pool
        let name: String
        /// The media pool id
        let mpid: MPID
        /// The path to where the pool stores its files
        let path: FilePath

        /// Creates a new pool
        /// - Parameter name: The friendly name for the pool
        /// - Parameter mpid: The pool id
        /// - Parameter path: The path to the working directory
        init(name: String, mpid: MPID, path: FilePath) throws {
            self.context = "[vDB::Pool (\(name))]"

            self.name = name
            self.mpid = mpid
            self.path = path

            let manager = FileManager.default
            var is_dir: ObjCBool = false

            // Check if the destination exists
            if manager.fileExists(atPath: path.string, isDirectory: &is_dir) {
                // If it is not a directory, error
                if !is_dir.boolValue {
                    VErr("Pool location '\(path)' does exist, but is not a directory")
                    throw CreationError("Pool location '\(path)' does exist, but is not a directory")
                }
            } else {
                // If it doesn't exist, create the new directory
                VInfo("Creating new pool at '\(path)'")
                try manager.createDirectory(at: URL(filePath: path.string), withIntermediateDirectories: true)
            }

            VInfo("Initialized pool \(name), referencing '\(path)'")
        }

        /// An error occured during pool creation
        struct CreationError: Error, LocalizedError {
            let errorDescription: String?

            init(_ description: String) {
                errorDescription = description
            }
        }

        /// Serializable information about a media pool
        struct Info : Encodable {
            let mpid: MPID
            let name: String
            let write: Bool
            let manage: Bool
        }

        /// Assign a group to this pool with some permissions and a quota
        /// - Parameter db: The database instance to use for execution
        /// - Parameter group: The group to assign
        /// - Parameter quota: The quota in bytes the group has on this pool
        /// - Parameter write: If the group is allowed to write to media in this pool
        /// - Parameter manage: If the group can create and remove media from this pool
        func assign(db: VDB, group: Group, quota: Int64, write: Bool, manage: Bool) throws {
            let t_gp = db.t_grouppools
            let query = t_gp.table.insert(or: .replace,
                                          t_gp.mpid <- self.mpid,
                                          t_gp.gid <- group.gid,
                                          t_gp.quota <- quota,
                                          t_gp.write <- write,
                                          t_gp.manage <- manage)
            try db.db.run(query)
        }

        /// Revokes a group from this pool, dropping all media access
        /// - Parameter db: The database instance to use for execution
        /// - Parameter group: The group to revoke
        func revoke(db: VDB, group: Group) throws {
            let t_gp = db.t_grouppools
            let query = t_gp.table.filter(t_gp.mpid == self.mpid && t_gp.gid == group.gid).delete()
            try db.db.run(query)
        }

        /// Returns an array of media that is in this pool and attached to the provided group
        /// - Parameter db: The db to use for this call
        /// - Parameter group: The group to search for
        func get_media(db: VDB, group: Group) throws -> [Media] {
            let tm = db.t_media
            var media: [Media] = []

            let query = tm.table.filter(tm.mpid == self.mpid && tm.gid == group.gid)

            for row in try db.db.prepare(query) {
                media.append(Media.from_row(db: db, pool: self, group: group, row: row))
            }

            return media
        }
    }

    /// Add a new pool to this database
    /// - Parameter pool: The pool to add
    func pool_add(_ pool: MediaPool) {
        self.mediapools[pool.mpid] = pool
        /// Add the pool to the `root` group. If this fails, we have another problem...
        try! pool.assign(db: self, group: try! self.group_select(gid: 0)!, quota: 0, write: true, manage: true)
    }

    /// Get a pool by its media pool id
    /// - Parameter mpid: The media pool id to search for
    func pool_get(mpid: MPID) -> MediaPool? {
        return self.mediapools[mpid]
    }
}
