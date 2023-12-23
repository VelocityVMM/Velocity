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

/// The media id, a UUID string
typealias MID = String

extension VDB {
    /// A piece of media in the Velocity database, being owned by a pool
    class Media : Loggable {
        /// The logging context
        internal let context: String = "[vDB::Media]"

        /// A reference to the velocity database for later use
        let db: VDB
        /// The pool this `Media` is stored in
        let pool: MediaPool
        /// The group this `Media` belongs to
        let group: Group
        /// The name
        let name: String
        /// The size in bytes
        let size: Int64
        /// The media id to identify this media uniquely
        let mid: MID
        /// The media type
        let type: String
        /// If this media should only be openable in read-only mode
        let readonly: Bool

        init(db: VDB, pool: MediaPool, group: Group, name: String, type: String, size: Int64, mid: MID, readonly: Bool) {
            self.db = db
            self.pool = pool
            self.group = group
            self.name = name
            self.type = type
            self.size = size
            self.mid = mid
            self.readonly = readonly
        }

        convenience init(db: VDB, info: Info, mid: MID) {
            self.init(
                db: db,
                pool: info.pool,
                group: info.group,
                name: info.name,
                type: info.type,
                size: info.size,
                mid: mid,
                readonly: info.readonly)
        }

        /// Returns the full file path to the media file
        func get_file_path() -> FilePath {
            return self.pool.path.appending(self.mid)
        }

        /// Tries to delete the media, including the underlying file
        func delete() throws {
            VTrace("Deleting media \(self.mid) @ \(self.get_file_path())")

            // We first delete the DB entry, that can be reverted if FS deletion fails
            try self.db.db.transaction {
                let query = self.db.t_media.table.filter(self.db.t_media.mid == self.mid).delete()
                try self.db.db.run(query)

                try FileManager.default.removeItem(atPath: self.get_file_path().string)
            }
        }

        /// Creates new media from the information provided, registering it to the supplied database
        /// - Parameter db: The database to register the new media in
        /// - Parameter info: The information to use for creation
        static func new(db: VDB, info: Info) throws -> Swift.Result<Media, Media.CreationError> {
            let uuid = UUID().uuidString
            let file_path = info.pool.path.appending(uuid)

            if try db.db.exists(db.t_media.table, db.t_media.name == info.name && db.t_media.mpid == info.pool.mpid) {
                return .failure(.Duplicate)
            }

            velocity.VInfo("Creating new file '\(info.name)' of \(info.size) bytes at \(file_path)", "[vDB::Media]")
            velocity.VWarn("TODO: Check for quotas", "[vDB::Media]")

            let media = Media(db: db, info: info, mid: uuid)
            try db.media_insert(media)
            return .success(media)
        }

        /// Creates and fills new media from the information provided, registering it to the supplied database. The supplied size will be used for the
        /// size to allocate
        /// - Parameter db: The database to register the new media in
        /// - Parameter info: The information to use for creation
        static func allocate(db: VDB, info: Info) throws -> Swift.Result<Media, Media.CreationError> {

            velocity.VInfo("Allocating new file '\(info.name)' of \(info.size) bytes", "[vDB::Media]")

            switch try self.new(db: db, info: info) {
            case .failure(let e):
                return .failure(e)
            case .success(let media):
                FileManager.default.createFile(atPath: media.get_file_path().string, contents: nil)

                let file = try FileDescriptor.open(media.get_file_path(), .writeOnly)

                let mib: Int64 = 1024 * 1024
                let count_mib = info.size / mib
                let rest_bytes = info.size % mib

                let one_byte = Data(count: 1)
                let one_mib = Data(count: Int(mib))

                // Write mib
                for _ in 0...count_mib {
                    try file.writeAll(one_mib)
                }

                // Write rest of bytes
                for _ in 0...rest_bytes-1 {
                    try file.writeAll(one_byte)
                }

                return .success(media)
            }
        }

        /// An error that occured during media creation
        enum CreationError : Error {
            case Duplicate
            case Quota
        }

        /// Creates a media from a supplied database row
        /// - Parameter db: The db to store internally
        /// - Parameter pool: The pool this media is part of
        /// - Parameter group: The group this media is associated with
        /// - Parameter row: The row to use for creation
        static func from_row(db: VDB, pool: MediaPool, group: Group, row: Row) -> Media {
            let t = db.t_media
            // TODO: Determine SIZE
            return Media(
                db: db,
                pool: pool,
                group: group,
                name: row[t.name],
                type: row[t.type],
                size: 0,
                mid: row[t.mid],
                readonly: row[t.readonly])
        }

        /// Removes this piece of media from the mediapool, the filesystem and the database
        func remove() throws {
            try FileManager.default.removeItem(atPath: self.get_file_path().string)

            let t_media = self.db.t_media
            let query = t_media.table.where(t_media.mid == self.mid).delete()
            try self.db.db.run(query)
        }

        /// A structure to bundle media information
        struct Info {
            /// The pool this `Media` is stored in
            let pool: MediaPool
            /// The group this `Media` belongs to
            let group: Group
            /// The name
            let name: String
            /// The type
            let type: String
            /// The size in bytes
            let size: Int64
            /// If this media should only be openable in read-only mode
            let readonly: Bool
        }
    }

    /// Creates new media from the information provided
    /// - Parameter info: The information to use for creation
    func media_new(info: Media.Info) throws -> Swift.Result<Media, Media.CreationError> {
        return try Media.new(db: self, info: info)
    }

    /// Creates and fills new media from the information provided. The supplied size will be used for the
    /// size to allocate
    /// - Parameter info: The information to use for creation
    func media_allocate(info: Media.Info) throws -> Swift.Result<Media, Media.CreationError> {
        return try Media.allocate(db: self, info: info)
    }

}
