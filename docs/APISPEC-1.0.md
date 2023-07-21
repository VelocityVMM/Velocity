# Velocity API specification `v 1.0`

This is a proposal for the `1.0` version of the Velocity API specification.

The Velocity API uses `JSON` as its language.

### Hirarchy

Velocity manages virtual machines and resources seperately.

For resources, velocity uses so-called "pools" and virtual machines are managed in "catalogs".

The API is divided into several namespaces:

- [`/u`](#namespace-u): User and group management
- [`/r`](#namespace-r): Resource management
- [`/c`](#namespace-c): Catalog management
- [`/v`](#namespace-v): Virtual machine management

### Errors

If the API enconters some kind of error, it will respond with a http-response code in a non-200 range and an error as follows:

```json
{
    "code": "<Error code>",
    "message": "<Some error message (optional)>"
}
```

Some additional fields may be added to the error response depending on calls but this layout is guaranteed.

Some http-response codes are fixed:

- `400 - Bad Request`: The request is missing fields

- `403 - Forbidden`: The request is missing the `authkey` for privileged actions

- `500 - Internal Server Error`: The server encountered an error while processing the request

# User and group management: `/u` <a name="namespace-u"></a>

Velocity's concept of users and groups is similar to that of Unix. The user- and group-ids are randomized to minimize attack vectors by guessing other users user-ids. Permissions, vm and data pools are always connected to groups due to them being able to be shared across users with a fair amount of granularity.

### User

Each user is identified by its unique `UID`, its username and password.

Every user automatically gets assigned to a group using the users `username`. Note that the `gid` of that group won't always be the same as the `uid`.

### Group

Velocity works with groups. There are some special groups with specific privileges:

- `root`: Has permission to do everything, users in this group are superusers (`gid = 0`).

- `usermanager`: Users that are in this group have the permission to create new users and groups and assign users to groups except `root`.

- `catalogmanager`: Can create and remove catalogs.

- `poolmanager`: Can create and manage resource pools.

### Available endpoints

Authentication:

- [`/u/auth` - POST](#post-u-auth): Authenticate as a user

- [`/u/auth` - DELETE](#delete-u-auth): Log out the current user

- [`/u/auth` - PATCH](#patch-u-auth): Reauthenticate

User and group management:

- [`/u/user` - PUT](#put-u-user): Create a new user

- [`/u/user` - DELETE](#delete-u-user): Remove a user

- [`/u/group` - PUT](#put-u-group): Create a new group

- [`/u/group` - DELETE](#delete-u-group): Remove a group

- [`/u/group/assign` - PUT](#put-u-group-assign): Assign a user to a group

- [`/u/group/assign` - DELETE](#delete-u-group-assign): Remove group membership

## `/u/auth` - POST <a name="post-u-auth"></a>

Velocity's authentication model works using so-called 'authkeys'. Every user that is currently authenticated gets such a key that has a certain validity window. Every privileged action that requires authentication requires this authkey to be sent with the request. To obtain such an authkey, a user can issue an authentication to this endpoint.

**Request:**

```json
{
    "username": "<username>",
    "password": "<password>"
}
```

The password and username get transmitted in plaintext. It is assumed that the connection to the API uses HTTPS.

**Response:**

- `200`: Authenticated

```json
{
    "authkey": "<authkey>",
    "expires": "<unix timestamp>"
}
```

- `403 - Forbidden`: Authentication failed - username or password do not match

Every authkey has an expiration date that is transmitted in the unix timestamp format. The key has to be renewed before this date is passed for the key to stay valid.

## `/u/auth` - DELETE <a name="delete-u-auth"></a>

If a user desires to drop the current `authkey` immediately, this endpoint can be used for that.

**Request:**

```json
{
    "authkey": "<authkey>"
}
```

**Response:**

- `200`: Authkey dropped

> **Note**
> 
> For security reasons, dropping a non-existing authkey does still result in a `200` response code.

## `/u/auth` - PATCH <a name="patch-u-auth"></a>

If an authkey lease is about to expire, this call can be used to create a new authkey using the expiring key.

> **Note**
> 
> This will immediately drop the old authkey in favor of the newly generated one.

**Request:**

```json
{
    "authkey": "<authkey>"
}
```

**Response:**

- `200`: Authkey refreshed

```json
{
    "authkey": "<new authkey>",
    "expires": "<unix timestamp>"
}
```

- `403`: Tried to renew a non-existing / expired authkey

## `/u/user` - PUT <a name="put-u-user"></a>

> **Note**
> 
> Only users that are in the `usermanager` group can create users

This call automatically creates a new group with the groupname set to `<username>` and assigns the new user to that.

**Request:**

```json
{
    "authkey": "<authkey>",
    "username": "<username>",
    "password": "<password>",
    "groups": ["<GID>"]
}
```

The groups field can be an empty array.

**Response:**

- `200`: User created

```json
{
    "uid": "<UID>",
    "username": "<username>",
    "groups": ["<GID>"]
}
```

- `403 - Forbidden`: The current user is not allowed to create new users

- `409 - Conflict`: A user with the supplied `username` does already exist

## `/u/user` - DELETE <a name="delete-u-user"></a>

> **Note**
> 
> Only users that are in the `usermanager` group can remove users

This call removes the user with the supplied `UID`. This also removes the user's group that is named the same as the user and all of its VMs and images.

**Request:**

```json
{
    "authkey": "<authkey>",
    "uid": "<UID>"
}
```

**Response:**

- `200`: User removed

- `403 - Forbidden`: The current user is not allowed to remove users

- `404 - Not Found`: No user with the supplied `uid` has been found

## `/u/group` - PUT <a id="put-u-group"></a>

> **Note**
> 
> Only users that are in the `usermanager` group can create groups

**Request:**

```json
{
    "authkey": "<authkey>",
    "groupname": "<groupname>"
}
```

**Response:**

- `200`: Group created

```json
{
    "gid": "<GID>",
    "groupname": "<groupname>"
}
```

- `401 - Unauthorized`: The current user is not allowed to create new groups

- `409 - Conflict`: A group with the supplied `groupname` does already exist

## `/u/group` - DELETE <a name="delete-u-group"></a>

> **Note**
> 
> Only users that are in the `usermanager` group can remove groups

This call removes all the VMs and images owned by this group.

**Request:**

```json
{
    "authkey": "<authkey>",
    "uid": "<UID>"
}
```

**Response:**

- `200`: Group removed

- `401 - Unauthorized`: The current user is not allowed to remove users

## `/u/group/assign` - PUT <a id="put-u-group-assign"></a>

Assign a user to groups:

> **Note**
> 
> Only users that are in the `usermanager` group can assign users to groups

**Request:**

```json
{
    "authkey": "<authkey>",
    "uid": "<UID>",
    "groups": ["<GID>"]
}
```

**Response:**

- `200`: Groups added

```json
{
    "uid": "<UID>",
    "groups": ["<GID>"]
}
```

The response lets the caller know which groups the user now belongs to.

- `403 - Forbidden`: The current user is not allowed to assignto groups

- `404 - Not Found`: The `uid` of the user to assign has not been found

- `406 - Not Acceptable`: A user in `usermanager` tried to assign to `root` group

## `/u/group/assign` - DELETE <a name="delete-u-group-assign"></a>

Remove a user from groups:

> **Note**
> 
> Only users that are in the `usermanager` group can remove users from groups

**Request:**

```json
{
    "authkey": "<authkey>",
    "uid": "<UID>",
    "groups": ["<GID>"]
}
```

**Response:**

- `200`: User removed from groups

```json
{
    "uid": "<UID>",
    "groups": ["<GID>"]
}
```

The response lets the caller know which groups the user now belongs to.

- `403 - Forbidden`: The current user is not allowed to remove from groups

- `404 - Not Found`: The `uid` of the user to remove has not been found

- `406 - Not Acceptable`: A user in `usermanager` tried to remove from `root` group

# Resource management: `/r` <a name="namespace-r"></a>

## Resource types:

**Storage: (`STID`):**

- Disk image

**NIC (`NICID`):**

- FileHandleNIC

- Bridgable NICS (autodetect)

# Catalog management: `/c` <a name="namespace-c"></a>

Velocity's virtual machines live in so-called catalog. Every catalog is part of a group, but it can be shared with other groups. This allows for granular control over permissions.

A catalog is identified by its unique catalog id `CID`.

A catalog can be shared with the following permissions:

- `manage`: Can manage the catalog (share...)

- `view`: Can see available virtual machines in this catalog

- `create`: Can create new virtual machines in this catalog

- `alter`: Can alter existing virtual machines in this catalog

- `remove`: Can remove virtual machines from this catalog

- `state`: Can change the current state of a virtual machine

- `interact`: Can interact with a virtual machine (rfb, console...)

### Available endpoints:

- [`/c` - PUT](#put-c): Create a new catalog

- [`/c` - DELETE](#delete-c): Remove a catalog

- [`/c/share`- GET](#get-c-share): List all current shares

- [`/c/share` - POST](#post-c-share): Share a catalog / update permissions

- [`/c/share` - DELETE](#delete-c-share): Revoke a share

## `/c` - PUT <a name="put-c"></a>

Create a new catalog and assign it to a group.

> **Note**
> 
> Only users in the `catalogmanager` group can create catalogs

**Request:**

A catalog has a `label` and a group that owns this catalog and has full read-write access.

```json
{
    "authkey": "<authkey>",
    "group": "<GID>",
    "label": "<catalog label>"
}
```

**Response:**

- `200`: Catalog created

```json
{
    "cid": "<CID>"
}
```

- `401 - Unauthorized`: The user isn't authorized to create new catalogs (`catalogmanager`)

- `404 - Not Found`: The group this catalog is assigned to does not exist or the user isn't member of it

## `/c` - DELETE <a name="delete-c"></a>

Remove a catalog.

> **Note**
> 
> Only users in the `catalogmanager` group can remove catalogs

> **Note**
> 
> This removes all of the virtual machines associated with this catalog

**Request:**

```json
{
    "authkey": "<authkey>",
    "cid": "<CID>"
}
```

**Response:**

- `200`: Catalog removed

- `401 - Unauthorized`: The user isn't authorized to remove catalogs (`catalogmanager`)

- `404 - Not Found`: The catalog has not been found or is not visible to the user

## `/c/share` - GET <a name="get-c-share"></a>

List all shares of the catalog

> **Note:**
> 
> The user has to have the `manage` permission for the catalog

**Request:**

```json
{
    "authkey": "<authkey>",
    "cid": "<CID>"
}
```

**Response:**

- `200`: OK

```json
{
    "cid": "<CID>",
    "shares": [
        {
            "gid": "<GID>",
            "manage": true,
            "view": true,
            "create": true,
            "alter": true,
            "remove": true,
            "state": true,
            "interact": true
        }
    ]
}
```

Every share is identified by its group id (`GID`) followed by its permissions

- `401 - Unauthorized`: The user does not have the `manage` permission

- `404 - Not Found`: The catalog has not been found or is not visible to the user / group

## `/c/share` - POST <a name="post-c-share"></a>

Share the catalog or alter an existing share

> **Note:**
> 
> The user has to have the `manage` permission for the catalog

> **Note:**
> 
> If the share does already exist, this will update the existing share with the new permissions

**Request:**

```json
{
    "authkey": "<authkey>",
    "cid": "<CID>",
    "gid": "<GID>",
    "manage": true,
    "view": true,
    "create": true,
    "alter": true,
    "remove": true,
    "state": true,
    "interact": true
}
```

**Response:**

- `200`: OK

```json
{
    "cid": "<CID>",
    "gid": "<GID>",
    "manage": true,
    "view": true,
    "create": true,
    "alter": true,
    "remove": true,
    "state": true,
    "interact": true
}
```

- `401 - Unauthorized`: The user does not have the `manage` permission

- `404 - Not Found`: The catalog has not been found or is not visible to the user / group

## `/c/share` - DELETE <a name="delete-c-share"></a>

Revoke a share for a group

> **Note:**
> 
> The user has to have the `manage` permission for the catalog

**Request:**

```json
{
    "authkey": "<authkey>",
    "cid": "<CID>",
    "gid": "<GID>"
}
```

**Response:**

- `200`: Share revoked

```json
{
    "cid": "<CID>",
    "gid": "<GID>"
}
```

- `401 - Unauthorized` - The user does not have the `manage` permission

- `404 - Not Found` - There is no share to revoke

# Virtual machine management: `/v` <a name="namespace-v"></a>

Velocity's main point is to manage virtual machines on the host and provide means of interacting with them over this API. A Virtual machine is part of a catalog. This allows virtual machines to be shared across users easily. A virtual machine links to different resources.

### States

A virtual machine can be in different states:

- `STOPPED`: The virtual machine is not running

- `STARTING`: The virtual machine is moving to the `RUNNING` state (hypervisor)

- `RUNNING`: The virtual machine is running

- `PAUSING`: The virtual machine is moving to the `PAUSED` state (hypervisor)

- `PAUSED`: The virtual machine is paused and waiting for resume

- `RESUMING`: The virtual machine is moving back to the `RUNNING` state after being in the `PAUSED` state (hypervisor)

- `STOPPING`: The virtual machine is moving to the `STOPPED` state (hypervisor)

### Types

There are several types of virtual machines that are supported:

- `EFI`: A virtual machine that boots an EFI environment
  
  - [`/v/efi` - PUT](#put-v-efi): Create a new  `EFI` virtual machine

- `KBOOT`: Direct kernel boot

- `MAC`: Virtualize MacOS

### Common endpoints:

- [`/v` - DELETE](#delete-v): Remove an existing virtual machine

- [`/v/state` - GET](#get-v-state): Query the current state of a virtual machine

- [`/v/state` - POST](#post-v-state): Request a state change for a virtual machine

## `/v/efi` - PUT <a name="put-v-efi"></a>

Create a new `EFI` virtual machine using the supplied data

**Request:**

```json
{
    "authkey": "<authkey>",
    "name": "<vm name>",
    "catalog": "<CID>",

    "cpu_count": "<amount of CPUs assigned>",
    "memory_size_mb": "<memory size in miB>",
    "displays": [
        {
            "description": "<description>",
            "width": "<width>",
            "height": "<height>"
        }
    ]
    "storage_devices": ["<STID>"],
    "nics": ["<NICID>"],

    "rosetta": true,
    "autostart": true
}
```

**Field descriptions:**

- `name`: A unique name in the group to identify this virtual machine

- `pool`: The poolid this VM belongs to

- `cpu_count`: The amount of virtual CPUs that should be available to the guest

- `memory_size_mb`: The amount of memory assigned to the guest in `miB`

- `displays`: An array of displays
  
  - `description`: A way if identifying this display
  
  - `width`: The width in `px`
  
  - `height`: The height in `px`

- `storage_devices`: An array of attached storage devices

- `nics`: An array of attached network devices

- `rosetta`: Whether to enable the rosetta `x86` translation layer if available on the host

- `autostart`: Whether to automatically start this virtual machine on Velocity startup

**Response:**

- `200`: Virtual machine created

```json
{
    "vmid": "<VMID>"
}
```

- `401 - Unauthorized`: The user can't create virtual machines or is not member of the assigned group

- `404 - Not Found`: A linked resource couldn't be found

```json
{
    "code": "...",
    "message": "...",
    "type": "<resource type>",
    "rid": "<RID>"
}
```

- `409 - Conflict`: A virtual machine in this catalog with the same name does already exist

```json
{
    "code": "...",
    "message": "...",
    "vmid": "<VMID of colliding VM>"
}
```

## `/v` - DELETE <a name="delete-v"></a>

Remove an existing virtual machine

**Request:**

```json
{
    "authkey": "<authkey>",
    "vmid": "<VMID>"
}
```

**Response:**

- `200`: Virtual machine deleted

- `401 - Unauthorized`: The user can't remove virtual machines or the virtual machine belongs to a group the user isn't part of

- `404 - Not Found`: A virtual machine with the supplied id was not found

## `/v/state` - GET <a name="get-v-state"></a>

Query the current state of a virtual machine

**Request:**

```json
{
    "authkey": "<authkey>",
    "vmid": "<VMID>"
}
```

**Response:**

- `200`: OK

```json
{
    "vmid": "<VMID>",
    "state": "<VM state>"
}
```

- `404 - Not Found`: The virtual machine is not found or the user has no access to it

## `/v/state` - POST <a name="post-v-state"></a>

Request a state change for the virtual machine. Valid states:

- `STOPPED`

- `RUNNING`

- `PAUSED`

**Request:**

```json
{
    "authkey": "<authkey>",
    "vmid": "<VMID>",
    "state": "<VM state>",
    "force": true
}
```

If the `force` flag is set to `true` state changes will be forceful (eg. shutdown being immediate instead of graceful)

**Response:**

- `200`: State changed

```json
{
    "vmid": "<VMID>",
    "state": "<VM state>"
}
```

- `208 - Already Reported`: The virtual machine is already in the requested state

```json
{
    "vmid": "<VMID>",
    "state": "<VM state>"
}
```

- `403 - Forbidden`: The state change is not possible

```json
{
    "code": "...",
    "message": "...",
    "vmid": "<VMID>",
    "req_state": "<VM state>",
    "cur_state": "<VM state>"
}
```

- `404 - Not Found`: The `VMID` is not available to the user or doesn't exist

- `500 - Internal Server Error`: A hypervisor error occured during state transition

```json
{
    "code": "...",
    "message": "...",
    "vmid": "<VMID>",
    "state": "<VM state>"
}
```
