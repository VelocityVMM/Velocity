//
// MIT License
//
// Copyright (c) 2023 zimsneexh
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
import Vapor

extension VAPI {
    /// Registers all endpoints withing the namespace `/m/media`
    func register_endpoints_m_media(route: RoutesBuilder) throws {

        route.post("list") { req in
            let request: Structs.M.MEDIA.LIST.POST.Req = try req.content.decode(Structs.M.MEDIA.LIST.POST.Req.self)

            guard let key = self.get_authkey(authkey: request.authkey) else {
                return try self.error(code: .UNAUTHORIZED)
            }

            let c_user = key.user

            guard try c_user.has_permission(permission: "velocity.media.list", group: nil) else {
                self.VDebug("\(c_user.info()) tried to list media for group \(request.gid): FORBIDDEN")
                return try self.error(code: .M_MEDIA_LIST_POST_PERMISSION)
            }

            guard let group = try self.db.group_select(gid: request.gid) else {
                self.VDebug("\(c_user.info()) tried to list media for group \(request.gid): GROUP NOT FOUND")
                return try self.error(code: .M_MEDIA_LIST_POST_GROUP_NOT_FOUND)
            }

            var media_info: [Structs.M.MEDIA.LIST.POST.MediaInfo] = []
            for media in try group.get_media() {
                media_info.append(Structs.M.MEDIA.LIST.POST.MediaInfo(
                    mid: media.mid,
                    mpid: media.pool.mpid,
                    name: media.name,
                    type: media.type,
                    size: media.size,
                    readonly: media.readonly))
            }

            self.VDebug("\(c_user.info()) listed media for \(group.info())")

            let response = Structs.M.MEDIA.LIST.POST.Res(media: media_info)
            var headers = HTTPHeaders()
            headers.add(name: .contentType, value: "application/json")

            return try Response(status: .ok, headers: headers, body: .init(data: self.encoder.encode(response)))
        }

        route.put("create") { req in
            let request: Structs.M.MEDIA.CREATE.PUT.Req = try req.content.decode(Structs.M.MEDIA.CREATE.PUT.Req.self)

            guard let key = self.get_authkey(authkey: request.authkey) else {
                return try self.error(code: .UNAUTHORIZED)
            }

            let user = key.user

            guard try user.has_permission(permission: "velocity.media.create", group: nil) else {
                self.VDebug("\(user.info()) tried to create new media '\(request.name)': FORBIDDEN")
                return try self.error(code: .M_MEDIA_CREATE_PUT_PERMISSION)
            }

            guard let pool = self.db.pool_get(mpid: request.mpid) else {
                self.VDebug("\(user.info()) tried to create new media '\(request.name)': MEDIAPOOL NOT FOUND")
                return try self.error(code: .M_MEDIA_CREATE_PUT_MEDIAPOOL_NOT_FOUND)
            }

            guard let group = try self.db.group_select(gid: request.gid) else {
                self.VDebug("\(user.info()) tried to create new media '\(request.name)': GROUP NOT FOUND")
                return try self.error(code: .M_MEDIA_CREATE_PUT_GROUP_NOT_FOUND)
            }

            guard try group.can_manage(pool: pool) else {
                self.VDebug("\(user.info()) tried to create media in pool \(pool.name): Group lacks 'manage' permission")
                return try self.error(code: .M_MEDIA_CREATE_PUT_GROUP_PERMISSION)
            }

            let media_info = VDB.Media.Info(pool: pool, group: group, name: request.name, type: request.type, size: request.size, readonly: false)

            switch try VDB.Media.allocate(db: self.db, info: media_info) {
            case .failure(let error):
                switch error {
                case .Duplicate:
                    self.VDebug("\(user.info()) tried to create new media '\(request.name)': DUPLICATE")
                    return try self.error(code: .M_MEDIA_CREATE_PUT_CONFLICT)
                case .Quota:
                    self.VDebug("\(user.info()) tried to create new media '\(request.name)': QUOTA SURPASSED")
                    return try self.error(code: .M_MEDIA_CREATE_PUT_QUOTA)
                }
            case .success(let media):
                let response = Structs.M.MEDIA.CREATE.PUT.Res(mid: media.mid, size: media.size)
                var headers = HTTPHeaders()
                headers.add(name: .contentType, value: "application/json")

                self.VDebug("\(user.info()) created new media '\(media.name)' of \(media.size) bytes: \(media.mid)")
                return try Response(status: .ok, headers: headers, body: .init(data: self.encoder.encode(response)))
            }
        }

        route.on(.PUT, "upload", body: .stream) { req -> EventLoopFuture<Response> in
            let promise = req.eventLoop.makePromise(of: Void.self)

            // MARK: Gather all fields

            guard let content_length = req.headers["Content-Length"].first else {
                return try self.promise_error(promise, code: .M_MEDIA_UPLOAD_PUT_CONTENT_LENGTH, "Field missing")
            }
            guard let content_length: Int64 = Int64(content_length) else {
                return try self.promise_error(promise, code: .M_MEDIA_UPLOAD_PUT_CONTENT_LENGTH, "Need a Int")
            }

            guard let authkey = req.headers["x-velocity-authkey"].first else {
                return try self.promise_error(promise, code: .M_MEDIA_UPLOAD_PUT_X_VELOCITY_AUTHKEY, "Field missing")
            }

            guard let mpid = req.headers["x-velocity-mpid"].first else {
                return try self.promise_error(promise, code: .M_MEDIA_UPLOAD_PUT_X_VELOCITY_MPID, "Field missing")
            }
            guard let mpid: MPID = Int64(mpid) else {
                return try self.promise_error(promise, code: .M_MEDIA_UPLOAD_PUT_X_VELOCITY_MPID, "Need a Int")
            }

            guard let gid = req.headers["x-velocity-gid"].first else {
                return try self.promise_error(promise, code: .M_MEDIA_UPLOAD_PUT_X_VELOCITY_GID, "Field missing")
            }
            guard let gid: GID = Int64(gid) else {
                return try self.promise_error(promise, code: .M_MEDIA_UPLOAD_PUT_X_VELOCITY_GID, "Need a Int")
            }

            guard let name = req.headers["x-velocity-name"].first else {
                return try self.promise_error(promise, code: .M_MEDIA_UPLOAD_PUT_X_VELOCITY_NAME, "Field missing")
            }

            guard let type = req.headers["x-velocity-type"].first else {
                return try self.promise_error(promise, code: .M_MEDIA_UPLOAD_PUT_X_VELOCITY_TYPE, "Field missing")
            }

            guard let readonly = req.headers["x-velocity-readonly"].first else {
                return try self.promise_error(promise, code: .M_MEDIA_UPLOAD_PUT_X_VELOCITY_READONLY, "Field missing")
            }

            guard let readonly: Bool = Bool(readonly) else {
                return try self.promise_error(promise, code: .M_MEDIA_UPLOAD_PUT_X_VELOCITY_READONLY, "Need a Bool")
            }

            // MARK: Check validity

            guard let key = self.get_authkey(authkey: authkey) else {
                return try self.promise_error(promise, code: .UNAUTHORIZED)
            }

            let c_user = key.user

            guard try c_user.has_permission(permission: "velocity.media.create", group: nil) else {
                self.VDebug("\(c_user.info()) tried to upload media '\(name)': FORBIDDEN")
                return try self.promise_error(promise, code: .M_MEDIA_UPLOAD_PUT_PERMISSION)
            }

            // MARK: Gather variables

            guard let pool = self.db.pool_get(mpid: mpid) else {
                self.VDebug("\(c_user.info()) tried to upload media '\(name)': MEDIAPOOL NOT FOUND")
                return try self.promise_error(promise, code: .M_MEDIA_UPLOAD_PUT_MEDIAPOOL_NOT_FOUND)
            }

            guard let group = try self.db.group_select(gid: gid) else {
                self.VDebug("\(c_user.info()) tried to upload media '\(name)': GROUP NOT FOUND")
                return try self.promise_error(promise, code: .M_MEDIA_UPLOAD_PUT_GROUP_NOT_FOUND)
            }

            guard try group.can_manage(pool: pool) else {
                self.VDebug("\(c_user.info()) tried to upload media to pool \(pool.name): Group lacks 'manage' permission")
                return try self.promise_error(promise, code: .M_MEDIA_UPLOAD_PUT_GROUP_PERMISSION)
            }

            // Create the media struct for uploading
            let media_info = VDB.Media.Info(pool: pool, group: group, name: name, type: type, size: content_length, readonly: readonly)
            let media_result = try self.db.media_new(info: media_info)

            // Extract the media from the Result type
            var new_media: VDB.Media? = nil
            switch media_result {
            case .failure(let error):
                switch error {
                case .Duplicate:
                    self.VDebug("\(c_user.info()) tried to create new media '\(name)': DUPLICATE")
                    return try self.promise_error(promise, code: .M_MEDIA_UPLOAD_PUT_CONFLICT)
                case .Quota:
                    self.VDebug("\(c_user.info()) tried to create new media '\(name)': QUOTA SURPASSED")
                    return try self.promise_error(promise, code: .M_MEDIA_UPLOAD_PUT_QUOTA)
                }
            case .success(let media):
                new_media = media
            }

            let media = new_media!

            // MARK: Upload

            FileManager.default.createFile(atPath: media.get_file_path().string, contents: nil, attributes: nil)

            let io = req.application.fileio
            return io.openFile(path: media.get_file_path().string, mode: .write, eventLoop: req.eventLoop).flatMap { handle -> EventLoopFuture<Response> in

                // The amount of uploaded bytes
                var uploaded_bytes = 0

                func handleChunks(promise: EventLoopPromise<Void>) {
                    req.body.drain { drainResult -> EventLoopFuture<Void> in
                        switch drainResult {
                        case .buffer(let chunk):
                            // Check for promised file size
                            uploaded_bytes += chunk.readableBytes
                            if uploaded_bytes > content_length {
                                self.VErr("Exceeded promised data size of \(content_length): \(uploaded_bytes)")
                                promise.succeed()
                                return req.eventLoop.future()
                            }

                            return io.write(fileHandle: handle, buffer: chunk, eventLoop: req.eventLoop).flatMap { _ in
                                return req.eventLoop.future()
                            }
                        case .error(let error):
                            promise.fail(error)
                            return req.eventLoop.future(error: error)
                        case .end:
                            promise.succeed(())
                            return req.eventLoop.future()
                        }
                    }
                }

                handleChunks(promise: promise)

                return promise.futureResult.always { result in
                    _ = try? handle.close()
                }.map {
                    if uploaded_bytes <= content_length {
                        self.VDebug("\(c_user.info()) uploaded new media '\(media.name)' of \(media.size) bytes: \(media.mid)")

                        let response_struct = VAPI.Structs.M.MEDIA.UPLOAD.PUT.Res(mid: media.mid, size_mib: media.size)
                        var headers = HTTPHeaders()
                        headers.add(name: .contentType, value: "application/json")

                        return try! Response(status: .ok, headers: headers, body: .init(data: self.encoder.encode(response_struct)))
                    } else {
                        return try! self.error(code: .M_MEDIA_UPLOAD_PUT_CONTENT_LENGTH)
                    }
                }
            }
        }
    }
}

extension VAPI.Structs.M {
    /// `/m/media`
    struct MEDIA {
        /// `/m/media/list`
        struct LIST {
            /// `/m/media/list` - POST
            struct POST {
                struct Req : Decodable {
                    let authkey: String
                    let gid: GID
                }
                struct Res : Encodable {
                    let media: [MediaInfo]
                }
                struct MediaInfo : Encodable {
                    let mid: MID
                    let mpid: MPID
                    let name: String
                    let type: String
                    let size: Int64
                    let readonly: Bool
                }
            }
        }
        /// `/m/media/create`
        struct CREATE {
            /// `/m/media/create` - PUT
            struct PUT {
                struct Req : Decodable {
                    let authkey: String
                    let mpid: MPID
                    let gid: Int64
                    let name: String
                    let type: String
                    let size: Int64
                }
                struct Res : Encodable {
                    let mid: MID
                    let size: Int64
                }
            }
        }
        /// `/m/media/upload`
        struct UPLOAD {
            /// `/m/media/upload` - PUT
            struct PUT {
                struct Res : Encodable {
                    let mid: MID
                    let size_mib: Int64
                }
            }
        }

    }
}
