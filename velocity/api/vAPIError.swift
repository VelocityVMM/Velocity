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
import Vapor

extension VAPI {
    /// An enumeration of all possible error codes that can be thrown by the Velocity API
    enum ErrorCode : Int64, Encodable {

        /// The endpoint is not implemented yet
        case NOT_IMPLEMENTED = 200

        /// An unauthorized request has been made
        case UNAUTHORIZED = 100

        /// `/u/auth - POST`: Authentication failed (username or password do not match)
        case U_AUTH_POST_AUTH_FAILED = 1100
        /// `/u/auth - PUT`: The old authkey hasn't been found
        case U_AUTH_PATCH_KEY_NOT_FOUND = 1400
        /// `/u/auth - PUT`: The old authkey has expired
        case U_AUTH_PATCH_KEY_EXPIRED = 1401

        // MARK: /u/user: 2xxx

        /// `/u/user - POST`: The `velocity.user.view` permission is missing
        case U_USER_POST_PERMISSION = 2100
        /// `/u/user - POST`: The requested user hasn't been found
        case U_USER_POST_NOT_FOUND = 2110

        /// `/u/user - PUT`: The `velocity.user.create` permission is missing
        case U_USER_PUT_PERMISSION = 2200
        /// `/u/user - PUT`: There is already a user with the same name
        case U_USER_PUT_CONFLICT = 2220

        /// `/u/user - DELETE`: The `velocity.user.remove` permission is missing
        case U_USER_DELETE_PERMISSION = 2300
        /// `/u/user - DELETE`: The user hasn't been found
        case U_USER_DELETE_NOT_FOUND = 2310

        // MARK: /u/user/list: 3xxx

        /// `/u/user/list - POST`: The `velocity.user.list` permission is missing
        case U_USER_LIST_POST_PERMISSION = 3100

        // MARK: /u/user/permission: 4xxx

        /// `/u/user/permission - PUT`: The `velocity.user.assign` permission is missing
        case U_USER_PERMISSION_PUT_PERMISSION = 4200
        /// `/u/user/permission - PUT`: The assigned user hasn't been found
        case U_USER_PERMISSION_PUT_USER_NOT_FOUND = 4210
        /// `/u/user/permission - PUT`: The assigned group hasn' been found
        case U_USER_PERMISSION_PUT_GROUP_NOT_FOUND = 4211
        /// `/u/user/permission - PUT`: The to assign permission hasn't been found
        case U_USER_PERMISSION_PUT_PERMISSION_NOT_FOUND = 4212
        /// `/u/user/permission - PUT`: The permission assigned is too high
        case U_USER_PERMISSION_PUT_HIGHER_PERMISSION = 4220

        /// `/u/user/permission - DELETE`: The `velocity.user.revoke` permission is missing
        case U_USER_PERMISSION_DELETE_PERMISSION = 4300
        /// `/u/user/permission - DELETE`: The revoked user hasn't been found
        case U_USER_PERMISSION_DELETE_USER_NOT_FOUND = 4310
        /// `/u/user/permission - DELETE`: The revoked group hasn't been found
        case U_USER_PERMISSION_DELETE_GROUP_NOT_FOUND = 4311
        /// `/u/user/permission - DELETE`: The to revoke permission hasn't been found
        case U_USER_PERMISSION_DELETE_PERMISSION_NOT_FOUND = 4312

        // MARK: /u/group: 5xxx

        /// `/u/group - POST`: The `velocity.group.view` permission is missing
        case U_GROUP_POST_PERMISSION = 5100
        /// `/u/group - POST`: The group hasn't been found
        case U_GROUP_POST_NOT_FOUND = 5110

        /// `/u/group - PUT`:The `velocity.group.create` permission is missing
        case U_GROUP_PUT_PERMISSION = 5200
        /// `/u/group - PUT`: The parent group hasn't been found
        case U_GROUP_PUT_PARENT_NOT_FUND = 5210
        /// `/u/group - PUT`: There does already exist a group with the same name within the parent group
        case U_GROUP_PUT_CONFLICT = 5220

        /// `/u/group - DELETE`: The `velocity.group.remove` permission is missing
        case U_GROUP_DELETE_PERMISSION = 5300
        /// `/u/group - DELETE`: The group to delete hasn't been found
        case U_GROUP_DELETE_NOT_FOUND = 5310

        // MARK: /m/pool/assign: 6xxx

        /// `/m/pool/assign - PUT`: The `velocity.pool.assign` permission is missing
        case M_POOL_ASSIGN_PUT_PERMISSION = 6200
        /// `/m/pool/assign - PUT`: The group hasn't been found
        case M_POOL_ASSIGN_PUT_GROUP_NOT_FOUND = 6210
        /// `/m/pool/assign - PUT`: The mediapool hasn't been found
        case M_POOL_ASSIGN_PUT_MEDIAPOOL_NOT_FOUND = 6211

        /// `/m/pool/assign - DELETE`: The `velocity.pool.revoke` permission is missing
        case M_POOL_ASSIGN_DELETE_PERMISSION = 6300
        /// `/m/pool/assign - DELETE`: The group hasn't been found
        case M_POOL_ASSIGN_DELETE_GROUP_NOT_FOUND = 6310
        /// `/m/pool/assign - DELETE`: The mediapool hasn't been found
        case M_POOL_ASSIGN_DELETE_MEDIAPOOL_NOT_FOUND = 6311

        // MARK: /m/pool/list: 7xxx

        /// `/m/pool/list - POST`: The `velocity.pool.list` permission is missing
        case M_POOL_LIST_POST_PERMISSION = 7100
        /// `/m/pool/list - POST`: The  `gid` hasn't been found
        case M_POOL_LIST_POST_GROUP_NOT_FOUND = 7110

        // MARK: /m/media/create: 8xxx

        /// `/m/media/create - PUT`: The `velocity.media.create` permission is missing
        case M_MEDIA_CREATE_PUT_PERMISSION = 8200
        /// `/m/media/create - PUT`: The group does not have the `manage` permission on the mediapool
        case M_MEDIA_CREATE_PUT_GROUP_PERMISSION = 8201
        /// `/m/media/create - PUT`: The  `gid` hasn't been found
        case M_MEDIA_CREATE_PUT_GROUP_NOT_FOUND = 8210
        /// `/m/media/create - PUT`: The  `mpid` hasn't been found
        case M_MEDIA_CREATE_PUT_MEDIAPOOL_NOT_FOUND = 8211
        /// `/m/media/create - PUT`: A file with the same `name` does already exist
        case M_MEDIA_CREATE_PUT_CONFLICT = 8220
        /// `/m/media/create - PUT`: The  quota has been surpassed
        case M_MEDIA_CREATE_PUT_QUOTA = 8221

        // MARK: /m/media/upload: 9xxx

        /// `/m/media/upload - PUT`: The `velocity.media.create` permission is missing
        case M_MEDIA_UPLOAD_PUT_PERMISSION = 9200
        /// `/m/media/upload - PUT`: The group does not have the `manage` permission on the mediapool
        case M_MEDIA_UPLOAD_PUT_GROUP_PERMISSION = 9201
        /// `/m/media/upload - PUT`: HTTP header: `Content-Length` field is missing
        case M_MEDIA_UPLOAD_PUT_CONTENT_LENGTH = 9210
        /// `/m/media/upload - PUT`: HTTP header: `x-velocity-authkey` field is missing
        case M_MEDIA_UPLOAD_PUT_X_VELOCITY_AUTHKEY = 9211
        /// `/m/media/upload - PUT`: HTTP header: `x-velocity-mpid` field is missing
        case M_MEDIA_UPLOAD_PUT_X_VELOCITY_MPID = 9212
        /// `/m/media/upload - PUT`: HTTP header: `x-velocity-gid` field is missing
        case M_MEDIA_UPLOAD_PUT_X_VELOCITY_GID = 9213
        /// `/m/media/upload - PUT`: HTTP header: `x-velocity-name` field is missing
        case M_MEDIA_UPLOAD_PUT_X_VELOCITY_NAME = 9214
        /// `/m/media/upload - PUT`: HTTP header: `x-velocity-type` field is missing
        case M_MEDIA_UPLOAD_PUT_X_VELOCITY_TYPE = 9215
        /// `/m/media/upload - PUT`: HTTP header: `x-velocity-readonly` field is missing
        case M_MEDIA_UPLOAD_PUT_X_VELOCITY_READONLY = 9216
        /// `/m/media/upload - PUT`: The  `gid` hasn't been found
        case M_MEDIA_UPLOAD_PUT_GROUP_NOT_FOUND = 9217
        /// `/m/media/upload - PUT`: The  `mpid` hasn't been found
        case M_MEDIA_UPLOAD_PUT_MEDIAPOOL_NOT_FOUND = 9218
        /// `/m/media/upload - PUT`: A file with the same `name` does already exist
        case M_MEDIA_UPLOAD_PUT_CONFLICT = 9220
        /// `/m/media/upload - PUT`: The  quota has been surpassed
        case M_MEDIA_UPLOAD_PUT_QUOTA = 9221
        /// `/m/media/upload - PUT`: The effective content lenght surpassed the promised `Content-Length`
        case M_MEDIA_UPLOAD_PUT_TOO_MANY_BYTES = 9222

        // MARK: /m/media/list: 10xxx

        /// `/m/media/list - POST`: The `velocity.media.list` permission is missing
        case M_MEDIA_LIST_POST_PERMISSION = 10100
        /// `/m/media/list - POST`: The `gid` has not been found
        case M_MEDIA_LIST_POST_GROUP_NOT_FOUND = 10110

        /// `/v/nic/list - POST`: The `velocity.nic.list` permission is missing
        case V_NIC_LIST_POST_PERMISSION = 11100

        /// `/v/vm/efi - PUT`: The `velocity.vm.create` permission is missing
        case V_VM_EFI_PUT_PERMISSION = 12200
        /// `/v/vm/efi - PUT`: The `gid` has not been found
        case V_VM_EFI_PUT_GROUP_NOT_FOUND = 12210
        /// `/v/vm/efi - PUT`: The `mid` of some media has not been found
        case V_VM_EFI_PUT_MEDIA_NOT_FOUND = 12211
        /// `/v/vm/efi - PUT`: The group for a certain `mid` has not been found
        case V_VM_EFI_PUT_MEDIA_GROUP_NOT_FOUND = 12212
        /// `/v/vm/efi - PUT`: The mediapool for a certain `mid` has not been found
        case V_VM_EFI_PUT_MEDIA_MEDIAPOOL_NOT_FOUND = 12213
        /// `/v/vm/efi - PUT`: The `nicid` of a host NIC has not been found
        case V_VM_EFI_PUT_HOST_NIC_NOT_FOUND = 12214
        /// `/v/vm/efi - PUT`: Some quota in the `CPU` space has been surpassed
        case V_VM_EFI_PUT_CPU_QUOTA = 12220
        /// `/v/vm/efi - PUT`: Some quota in the `MEMORY` space has been surpassed
        case V_VM_EFI_PUT_MEMORY_QUOTA = 12221
        /// `/v/vm/efi - PUT`: Some quota in the `MEDIA` space has been surpassed
        case V_VM_EFI_PUT_MEDIA_QUOTA = 12222
        /// `/v/vm/efi - PUT`: There is already a VM with the same `name` in the group
        case V_VM_EFI_PUT_CONFLICT = 12223
        /// `/v/vm/efi - PUT`: There is already display with the same `name` in the VM
        case V_VM_EFI_PUT_DISPLAY_CONFLICT = 12224
        /// `/v/vm/efi - PUT`: An invalid `mode` has been supplied for a disk
        case V_VM_EFI_PUT_DISK_MODE = 12225
        /// `/v/vm/efi - PUT`: An invalid `type` has been supplied for a nic
        case V_VM_EFI_PUT_NIC_TYPE = 12226
        /// `/v/vm/efi - PUT`: A NIC with type `BRIDGE` has been used, but no host NIC was supplied
        case V_VM_EFI_PUT_HOST_NIC_REQUIRED = 12227

        // MARK: /v/vm/state: 11xxx

        /// `/v/vm/state - POST`: The `velocity.vm.view` permission is missing
        case V_VM_STATE_POST_PERMISSION = 13100
        /// `/v/vm/state - POST`: The requested VMID has not been found
        case V_VM_STATE_POST_VM_NOT_FOUND = 13110

        /// `/v/vm/state - PUT`: The `velocity.vm.state` permission is missing
        case V_VM_STATE_PUT_PERMISSION = 13200
        /// `/v/vm/state - PUT`: The requested VMID has not been found
        case V_VM_STATE_PUT_VM_NOT_FOUND = 13210
        /// `/v/vm/state - PUT`: The requested state transition can not be completed
        case V_VM_STATE_PUT_NOT_ALLOWED = 13220

        // MARK: /v/vm: 16xxx

        /// `/v/vm - POST`: The requested VMID has not been found
        case V_VM_POST_VM_NOT_FOUND = 16210

        // MARK: /v/vm/list: 17xxx

        /// `/v/vm/list - POST`: The group has not been found
        case V_VM_LIST_POST_GROUP_NOT_FOUND = 17210

    }
}

extension VAPI.ErrorCode {
    /// Returns the matching `HTTP` status code for an error code
    func get_http_status() -> HTTPStatus {
        switch self {

        case .NOT_IMPLEMENTED: return .notImplemented

        case .UNAUTHORIZED: return .unauthorized

        // /u/auth
        case .U_AUTH_POST_AUTH_FAILED: return .forbidden
        case .U_AUTH_PATCH_KEY_NOT_FOUND: return .forbidden
        case .U_AUTH_PATCH_KEY_EXPIRED: return .forbidden


        // /u/user - POST
        case .U_USER_POST_PERMISSION: return .forbidden
        case .U_USER_POST_NOT_FOUND: return .notFound

        // /u/user - PUT
        case .U_USER_PUT_PERMISSION: return .forbidden
        case .U_USER_PUT_CONFLICT: return .conflict

        // /u/user - DELETE
        case .U_USER_DELETE_PERMISSION: return .forbidden
        case .U_USER_DELETE_NOT_FOUND: return .notFound

        // /u/user/list - POST
        case .U_USER_LIST_POST_PERMISSION: return .forbidden

        // /u/user/permission - PUT
        case .U_USER_PERMISSION_PUT_PERMISSION: return .forbidden
        case .U_USER_PERMISSION_PUT_USER_NOT_FOUND: return .notFound
        case .U_USER_PERMISSION_PUT_GROUP_NOT_FOUND: return .notFound
        case .U_USER_PERMISSION_PUT_PERMISSION_NOT_FOUND: return .notFound
        case .U_USER_PERMISSION_PUT_HIGHER_PERMISSION: return .forbidden

        // /u/user/permission - DELETE
        case .U_USER_PERMISSION_DELETE_PERMISSION: return .forbidden
        case .U_USER_PERMISSION_DELETE_USER_NOT_FOUND: return .notFound
        case .U_USER_PERMISSION_DELETE_GROUP_NOT_FOUND: return .notFound
        case .U_USER_PERMISSION_DELETE_PERMISSION_NOT_FOUND: return .notFound

        // /u/group - POST
        case .U_GROUP_POST_PERMISSION: return .forbidden
        case .U_GROUP_POST_NOT_FOUND: return .notFound

        // /u/group - PUT
        case .U_GROUP_PUT_PERMISSION: return .forbidden
        case .U_GROUP_PUT_PARENT_NOT_FUND: return .notFound
        case .U_GROUP_PUT_CONFLICT: return .conflict

        // /u/group - DELETE
        case .U_GROUP_DELETE_PERMISSION: return .forbidden
        case .U_GROUP_DELETE_NOT_FOUND: return .notFound

        // /m/pool/assign - PUT
        case .M_POOL_ASSIGN_PUT_PERMISSION: return .forbidden
        case .M_POOL_ASSIGN_PUT_GROUP_NOT_FOUND: return .notFound
        case .M_POOL_ASSIGN_PUT_MEDIAPOOL_NOT_FOUND: return .notFound

        // /m/pool/assign - DELETE
        case .M_POOL_ASSIGN_DELETE_PERMISSION: return .forbidden
        case .M_POOL_ASSIGN_DELETE_GROUP_NOT_FOUND: return .notFound
        case .M_POOL_ASSIGN_DELETE_MEDIAPOOL_NOT_FOUND: return .notFound

        // /m/pool/list - POST
        case .M_POOL_LIST_POST_PERMISSION: return .forbidden
        case .M_POOL_LIST_POST_GROUP_NOT_FOUND: return .notFound

        // /m/media/create - PUT
        case .M_MEDIA_CREATE_PUT_PERMISSION: return .forbidden
        case .M_MEDIA_CREATE_PUT_GROUP_PERMISSION: return .forbidden
        case .M_MEDIA_CREATE_PUT_GROUP_NOT_FOUND: return .notFound
        case .M_MEDIA_CREATE_PUT_MEDIAPOOL_NOT_FOUND: return .notFound
        case .M_MEDIA_CREATE_PUT_CONFLICT: return .conflict
        case .M_MEDIA_CREATE_PUT_QUOTA: return .notAcceptable

        // /m/media/upload - PUT
        case .M_MEDIA_UPLOAD_PUT_PERMISSION: return .forbidden
        case .M_MEDIA_UPLOAD_PUT_GROUP_PERMISSION: return .forbidden
        case .M_MEDIA_UPLOAD_PUT_CONTENT_LENGTH: return .badRequest
        case .M_MEDIA_UPLOAD_PUT_X_VELOCITY_AUTHKEY: return .badRequest
        case .M_MEDIA_UPLOAD_PUT_X_VELOCITY_MPID: return .badRequest
        case .M_MEDIA_UPLOAD_PUT_X_VELOCITY_GID: return .badRequest
        case .M_MEDIA_UPLOAD_PUT_X_VELOCITY_NAME: return .badRequest
        case .M_MEDIA_UPLOAD_PUT_X_VELOCITY_TYPE: return .badRequest
        case .M_MEDIA_UPLOAD_PUT_X_VELOCITY_READONLY: return .badRequest
        case .M_MEDIA_UPLOAD_PUT_GROUP_NOT_FOUND: return .notFound
        case .M_MEDIA_UPLOAD_PUT_MEDIAPOOL_NOT_FOUND: return .notFound
        case .M_MEDIA_UPLOAD_PUT_CONFLICT: return .conflict
        case .M_MEDIA_UPLOAD_PUT_QUOTA: return .notAcceptable
        case .M_MEDIA_UPLOAD_PUT_TOO_MANY_BYTES: return .payloadTooLarge

        // /m/media/list - POST
        case .M_MEDIA_LIST_POST_PERMISSION: return .forbidden
        case .M_MEDIA_LIST_POST_GROUP_NOT_FOUND: return .notFound

        // /v/nic/list - POST
        case .V_NIC_LIST_POST_PERMISSION: return .forbidden


        // /v/vm/efi - PUT
        case .V_VM_EFI_PUT_PERMISSION: return .forbidden
        case .V_VM_EFI_PUT_GROUP_NOT_FOUND: return .notFound
        case .V_VM_EFI_PUT_MEDIA_NOT_FOUND: return .notFound
        case .V_VM_EFI_PUT_MEDIA_GROUP_NOT_FOUND: return .notFound
        case .V_VM_EFI_PUT_MEDIA_MEDIAPOOL_NOT_FOUND: return .notFound
        case .V_VM_EFI_PUT_HOST_NIC_NOT_FOUND: return .notFound
        case .V_VM_EFI_PUT_CPU_QUOTA: return .notAcceptable
        case .V_VM_EFI_PUT_MEMORY_QUOTA: return .notAcceptable
        case .V_VM_EFI_PUT_MEDIA_QUOTA: return .notAcceptable
        case .V_VM_EFI_PUT_CONFLICT: return .conflict
        case .V_VM_EFI_PUT_DISPLAY_CONFLICT: return .conflict
        case .V_VM_EFI_PUT_DISK_MODE: return .notAcceptable
        case .V_VM_EFI_PUT_NIC_TYPE: return .notAcceptable
        case .V_VM_EFI_PUT_HOST_NIC_REQUIRED: return .notAcceptable

        // /v/vm/state - POST
        case .V_VM_STATE_POST_PERMISSION: return .forbidden
        case .V_VM_STATE_POST_VM_NOT_FOUND: return .notFound

        // /v/vm/state - PUT
        case .V_VM_STATE_PUT_PERMISSION: return .forbidden
        case .V_VM_STATE_PUT_VM_NOT_FOUND: return .notFound
        case .V_VM_STATE_PUT_NOT_ALLOWED: return .notAcceptable

        // /v/vm - POST
        case .V_VM_POST_VM_NOT_FOUND: return .notFound

        // /v/vm/list - POST
        case .V_VM_LIST_POST_GROUP_NOT_FOUND: return .notFound
        }
    }

    /// Returns the matching error message for an error code
    func get_message() -> String {
        switch self {

        case .NOT_IMPLEMENTED: return "Feature not implemented"

        case .UNAUTHORIZED: return "Unauthorized: Authkey is invalid or not present"

        // /u/auth
        case .U_AUTH_POST_AUTH_FAILED: return "Authentication failed"
        case .U_AUTH_PATCH_KEY_NOT_FOUND: return "Authkey does not exist"
        case .U_AUTH_PATCH_KEY_EXPIRED: return "Authkey has expired"

        // /u/user - POST
        case .U_USER_POST_PERMISSION: return "Permission 'velocity.user.view' is needed"
        case .U_USER_POST_NOT_FOUND: return "User has not been found"

        // /u/user - PUT
        case .U_USER_PUT_PERMISSION: return "Permission 'velocity.user.create' is needed"
        case .U_USER_PUT_CONFLICT: return "A user with the same name exists"

        // /u/user - DELETE
        case .U_USER_DELETE_PERMISSION: return "Permission 'velocity.user.remove' is needed"
        case .U_USER_DELETE_NOT_FOUND: return "User has not been found"

        // /u/user/list - POST
        case .U_USER_LIST_POST_PERMISSION: return "Permission 'velocity.user.list' is needed"

        // /u/user/permission - PUT
        case .U_USER_PERMISSION_PUT_PERMISSION: return "Permission 'velocity.user.assign' is needed"
        case .U_USER_PERMISSION_PUT_USER_NOT_FOUND: return "User has not been found"
        case .U_USER_PERMISSION_PUT_GROUP_NOT_FOUND: return "Group has not been found"
        case .U_USER_PERMISSION_PUT_PERMISSION_NOT_FOUND: return "Permission has not been found"
        case .U_USER_PERMISSION_PUT_HIGHER_PERMISSION: return "Assigned permission is too high"

        // /u/user/permission - DELETE
        case .U_USER_PERMISSION_DELETE_PERMISSION: return "Permission 'velocity.user.revoke' is needed"
        case .U_USER_PERMISSION_DELETE_USER_NOT_FOUND: return "User has not been found"
        case .U_USER_PERMISSION_DELETE_GROUP_NOT_FOUND: return "Group has not been found"
        case .U_USER_PERMISSION_DELETE_PERMISSION_NOT_FOUND: return "Permission has not been found"

        // /u/group - POST
        case .U_GROUP_POST_PERMISSION: return "Permission 'velocity.group.view' is needed"
        case .U_GROUP_POST_NOT_FOUND: return "Group has not been found"

        // /u/group - PUT
        case .U_GROUP_PUT_PERMISSION: return "Permission 'velocity.group.create' is needed"
        case .U_GROUP_PUT_PARENT_NOT_FUND: return "Parent group has not been found"
        case .U_GROUP_PUT_CONFLICT: return "A group with the same name exists within the parent group"

        // /u/group - DELETE
        case .U_GROUP_DELETE_PERMISSION: return "Permission 'velocity.group.remove' is needed"
        case .U_GROUP_DELETE_NOT_FOUND: return "Group has not been found"

        // /m/pool/assign - PUT
        case .M_POOL_ASSIGN_PUT_PERMISSION: return "Permission 'velocity.pool.assign' is needed"
        case .M_POOL_ASSIGN_PUT_GROUP_NOT_FOUND: return "Group has not been found"
        case .M_POOL_ASSIGN_PUT_MEDIAPOOL_NOT_FOUND: return "Mediapool has not been found"

        // /m/pool/assign - DELETE
        case .M_POOL_ASSIGN_DELETE_PERMISSION: return "Permission 'velocity.pool.revoke' is needed"
        case .M_POOL_ASSIGN_DELETE_GROUP_NOT_FOUND: return "Group has not been found"
        case .M_POOL_ASSIGN_DELETE_MEDIAPOOL_NOT_FOUND: return "Mediapool has not been found"

        // /m/pool/list - POST
        case .M_POOL_LIST_POST_PERMISSION: return "Permission 'velocity.pool.list' is needed"
        case .M_POOL_LIST_POST_GROUP_NOT_FOUND: return "Group has not been found"

        // /m/media/create - PUT
        case .M_MEDIA_CREATE_PUT_PERMISSION: return "Permission 'velocity.media.create' is needed"
        case .M_MEDIA_CREATE_PUT_GROUP_PERMISSION: return "The group does not have the 'manage' permission on the mediapool"
        case .M_MEDIA_CREATE_PUT_GROUP_NOT_FOUND: return "Group has not been found"
        case .M_MEDIA_CREATE_PUT_MEDIAPOOL_NOT_FOUND: return "Mediapool has not been found"
        case .M_MEDIA_CREATE_PUT_CONFLICT: return "A file with the same name does already exist in this pool"
        case .M_MEDIA_CREATE_PUT_QUOTA: return "Some quota has been surpassed"

        // /m/media/upload - PUT
        case .M_MEDIA_UPLOAD_PUT_PERMISSION: return "Permission 'velocity.media.create' is needed"
        case .M_MEDIA_UPLOAD_PUT_GROUP_PERMISSION: return "The group does not have the 'manage' permission on the mediapool"
        case .M_MEDIA_UPLOAD_PUT_CONTENT_LENGTH: return "The HTTP header is missing the 'Content-Length' field"
        case .M_MEDIA_UPLOAD_PUT_X_VELOCITY_AUTHKEY: return "The HTTP header is missing the 'x-velocity-authkey' field"
        case .M_MEDIA_UPLOAD_PUT_X_VELOCITY_MPID: return "The HTTP header is missing the 'x-velocity-mpid' field"
        case .M_MEDIA_UPLOAD_PUT_X_VELOCITY_GID: return "The HTTP header is missing the 'x-velocity-gid' field"
        case .M_MEDIA_UPLOAD_PUT_X_VELOCITY_NAME: return "The HTTP header is missing the 'x-velocity-name' field"
        case .M_MEDIA_UPLOAD_PUT_X_VELOCITY_TYPE: return "The HTTP header is missing the 'x-velocity-type' field"
        case .M_MEDIA_UPLOAD_PUT_X_VELOCITY_READONLY: return "The HTTP header is missing the 'x-velocity-readonly' field"
        case .M_MEDIA_UPLOAD_PUT_GROUP_NOT_FOUND: return "Group has not been found"
        case .M_MEDIA_UPLOAD_PUT_MEDIAPOOL_NOT_FOUND: return "Mediapool has not been found"
        case .M_MEDIA_UPLOAD_PUT_CONFLICT: return "A file with the same name does already exist in this pool"
        case .M_MEDIA_UPLOAD_PUT_QUOTA: return "Some quota has been surpassed"
        case .M_MEDIA_UPLOAD_PUT_TOO_MANY_BYTES: return "More bytes were submitted than promised by 'Content-Length'"

        // /m/media/list - POST
        case .M_MEDIA_LIST_POST_PERMISSION: return "Permission 'velocity.media.list' is needed"
        case .M_MEDIA_LIST_POST_GROUP_NOT_FOUND: return "Group has not been found"

        // /v/nic/list - POST
        case .V_NIC_LIST_POST_PERMISSION: return "Permission 'velocity.nic.list' is needed"

        // /v/vm/efi - PUT
        case .V_VM_EFI_PUT_PERMISSION: return "Permission 'velocity.vm.create' is needed"
        case .V_VM_EFI_PUT_GROUP_NOT_FOUND: return "Group has not been found"
        case .V_VM_EFI_PUT_MEDIA_NOT_FOUND: return "Media has not been found"
        case .V_VM_EFI_PUT_MEDIA_GROUP_NOT_FOUND: return "The owning group has not been found"
        case .V_VM_EFI_PUT_MEDIA_MEDIAPOOL_NOT_FOUND: return "The owning mediapool has not been found"
        case .V_VM_EFI_PUT_HOST_NIC_NOT_FOUND: return "Host NIC has not been found"
        case .V_VM_EFI_PUT_CPU_QUOTA: return "CPU quota surpassed"
        case .V_VM_EFI_PUT_MEMORY_QUOTA: return "Memory quota surpassed"
        case .V_VM_EFI_PUT_MEDIA_QUOTA: return "Media quota surpassed"
        case .V_VM_EFI_PUT_CONFLICT: return "A VM with the same name does already exist in this group"
        case .V_VM_EFI_PUT_DISPLAY_CONFLICT: return "A display with the same name does already exist for the VM"
        case .V_VM_EFI_PUT_DISK_MODE: return "An invalid attachment mode has been used for a disk"
        case .V_VM_EFI_PUT_NIC_TYPE: return "An invalid interface type has been used for a NIC"
        case .V_VM_EFI_PUT_HOST_NIC_REQUIRED: return "A NIC of type 'BRIDGE' needs a host NIC"

        // /v/vm/state - POST
        case .V_VM_STATE_POST_PERMISSION: return "Permission 'velocity.vm.view' is needed"
        case .V_VM_STATE_POST_VM_NOT_FOUND: return "Virtual machine has not been found"

        // /v/vm/state - PUT
        case .V_VM_STATE_PUT_PERMISSION: return "Permission 'velocity.vm.state' is needed"
        case .V_VM_STATE_PUT_VM_NOT_FOUND: return "Virtual machine has not been found"
        case .V_VM_STATE_PUT_NOT_ALLOWED: return "State transition not allowed"

        // /v/vm - POST
        case .V_VM_POST_VM_NOT_FOUND: return "Virtual machine has not been found or is not accessible"

        // /v/vm/list - POST
        case .V_VM_LIST_POST_GROUP_NOT_FOUND: return "Group has not been found"
        }
    }
}

extension VAPI {
    /// An error thrown by the Velocity API
    struct Error : Encodable {
        /// The error code
        let code: ErrorCode
        /// A matching message
        let message: String
    }

    /// Resolves the promise but embeds a error struct into the Response
    /// - Parameter response: The eventloop promise to resolve
    /// - Parameter code: The code of the error
    func promise_error(_ promise: EventLoopPromise<Void>, code: ErrorCode) throws -> EventLoopFuture<Response> {
        let response = try self.error(code: code)
        promise.succeed()
        return promise.futureResult.always { r in }.map {
            return response
        }
    }

    /// Construct a new error from an error code and an additional string
    /// - Parameter code: The error code to return
    /// - Parameter additional: The additional message
    func error(code: ErrorCode, _ additional: String? = nil) throws -> Response {
        var msg = "\(code.get_message())"
        if let additional = additional {
            msg = "\(code.get_message()): \(additional)"
        }

        let error = Error(code: code, message: msg)

        VTrace("ERROR (\(code.get_http_status())): \(error)")

        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "application/json")

        return try Response(status: code.get_http_status(), headers: headers, body: .init(data: self.encoder.encode(error)))
    }

    /// Resolves the promise but embeds a error struct with additional information into the Response
    /// - Parameter response: The eventloop promise to resolve
    /// - Parameter code: The code of the error
    /// - Parameter additional: The additional message
    func promise_error(_ promise: EventLoopPromise<Void>, code: ErrorCode, _ additional: String) throws -> EventLoopFuture<Response> {
        let response = try self.error(code: code, additional)
        promise.succeed()
        return promise.futureResult.always { r in }.map {
            return response
        }
    }
}
