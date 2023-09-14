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
  
  - [`/v/efi` - PUT](#put-v-efi): Create a new `EFI` virtual machine

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
