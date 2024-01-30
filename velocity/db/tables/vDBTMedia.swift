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
import SQLite

extension VDB {
    /// The `media` table
    class TMedia : Loggable {
        /// The logging context
        internal let context: String = "[vDB::TMedia]";

        /// The `media` table
        let table = Table("media")

        /// The name for the media
        let name = Expression<String>("name")
        /// The type of media
        let type = Expression<String>("type")
        /// The unique media id
        let mid = Expression<MID>("mid")
        /// The media pool id the media is stored in
        let mpid = Expression<MPID>("pid")
        /// Thr group id the media is part of
        let gid = Expression<GID>("gid")
        /// If media should be read-only
        let readonly = Expression<Bool>("readonly")

        /// Ensures the table exists
        init(db: Connection, groups: Groups) throws {
            VDebug("Ensuring 'media' table...")
            // Setup the table
            try db.run(self.table.create(ifNotExists: true) {t in
                t.column(self.name)
                t.column(self.type)
                t.column(self.mid)
                t.column(self.mpid)
                t.column(self.gid)
                t.column(self.readonly)

                t.primaryKey(self.mid)
                t.unique(self.mpid, self.name)

                t.foreignKey(self.gid, references: groups.table, groups.gid)
            })
        }

        /// Inserts or replaces media from its parameters into this table
        /// - Parameter db: The database to use
        func insert(db: Connection, name: String, type: String, mid: MID, mpid: MPID, gid: GID, readonly: Bool) throws {
            let query = self.table.insert(
                self.name <- name,
                self.type <- type,
                self.mid <- mid,
                self.mpid <- mpid,
                self.gid <- gid,
                self.readonly <- readonly)

            try db.run(query)
        }

        /// Inserts or replaces media in this table
        /// - Parameter db: The database to use
        /// - Parameter media: The media to insert
        func insert(db: Connection, _ media: Media) throws {
            try self.insert(db: db, name: media.name, type: media.type, mid: media.mid, mpid: media.pool.mpid, gid: media.group.gid, readonly: media.readonly)
        }

        /// Select a piece of media from the database
        /// - Parameter db: The VDB to use for selecting
        /// - Parameter mid: The `mid` of the piece of media to select
        static func select(db: VDB, mid: MID) throws -> Swift.Result<Media, SelectError> {
            guard let row = try db.db.pluck(db.t_media.table.filter(db.t_media.mid == mid)) else {
                return .failure(.MediaNotFound)
            }

            guard let group = try db.group_select(gid: row[db.t_media.gid]) else {
                return .failure(.GroupNotFound)
            }

            guard let pool = db.pool_get(mpid: row[db.t_media.mpid]) else {
                return .failure(.MediapoolNotFound)
            }

            return .success(Media.from_row(db: db, pool: pool, group: group, row: row))
        }

        /// An error that occured during selection
        enum SelectError : Error {
            /// The `mid` does not exist
            case MediaNotFound
            /// The `gid` does not exist
            case GroupNotFound
            /// The `mpid` does not exist, maybe the pool is no longer attached?
            case MediapoolNotFound
        }
    }

    /// Inserts or replaces media from its parameters into this table
    func media_insert(name: String, type: String, mid: MID, mpid: MPID, gid: GID, readonly: Bool) throws {
        try self.t_media.insert(db: self.db, name: name, type: type, mid: mid, mpid: mpid, gid: gid, readonly: readonly)
    }

    /// Inserts or replaces media in this table
    /// - Parameter media: The media to insert
    func media_insert(_ media: Media) throws {
        try self.t_media.insert(db: self.db, media)
    }

    /// Select a piece of media from the database
    /// - Parameter mid: The `mid` of the piece of media to select
    func media_select(mid: MID) throws -> Swift.Result<Media, TMedia.SelectError> {
        return try TMedia.select(db: self, mid: mid)
    }
}
