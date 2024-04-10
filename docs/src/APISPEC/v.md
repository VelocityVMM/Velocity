# Virtual machine management

Velocity's main purpose is to manage virtual machines. This is the place for that.

## A word about `NICs` <a name='nic-info'></a>

Network devices are a tricky thing, especially `bridge` devices. Velocity gives the job of assigning host nics to the administrator. As with media pools, the administrator is responsible for providing a stable `NICID` that the virtual `NICs` can use if they operate in `BRIDGE` mode.

## VM states <a name="vm-states"></a>

A virtual machine can be in one of the following states:

- `STOPPED`: The virtual machine is not running

- `STARTING`: The virtual machine is moving to the `RUNNING` state (hypervisor)

- `RUNNING`: The virtual machine is running

- `PAUSING`: The virtual machine is moving to the `PAUSED` state (hypervisor)

- `PAUSED`: The virtual machine is paused and waiting for resume

- `RESUMING`: The virtual machine is moving back to the `RUNNING` state after being in the `PAUSED` state (hypervisor)

- `STOPPING`: The virtual machine is moving to the `STOPPED` state (hypervisor)

A user can request state changes from the server, but can only transition to those that are not marked with `(hypervisor)`.

### Available endpoints

[Virtual machine management](#v-vm)

- VM management

  - [`/v/vm/list` - POST](#post-v-vm-list): List all available virtual machines

  - [`/v/vm` - POST](#post-v-vm): Get information about a virtual machine

- VM creation

  - [`/v/vm/efi` - PUT](#put-v-vm-efi): Create a `EFI` virtual machine

- VM state management

  - [`/v/vm/state` - POST](#post-v-vm-state): Get the current VM state

  - [`/v/vm/state` - PUT](#put-v-vm-state): Request a VM state change

- VM management

[NIC management](#v-nic)

- [`/v/nic/list` - POST](#post-v-nic-list): List available host NICs

# Virtual machine management <a name="v-vm"></a>

# `/v/vm/list` - POST <a name="post-v-vm-list"></a>

List all available virtual machines for a group

> **Note**
>
> The calling user needs the `velocity.vm.view` permission on the target group

**Request:**

```json
{
  "authkey": "<authkey>",
  "gid": "<GID>"
}
```

**Response:**

- `200`:

```json
{
  "vms": [
    {
      "vmid": "<VMID>",
      "name": "<Name>",
      "cpus": "<CPU count>",
      "memory_mib": "<Memory in MiB>",
      "state": "<VM state>"
    }
  ]
}
```

- `401 - Unauthorized`: The calling user lacks permissions

- `404 - Not Found`: The `GID` couldn't be found

# `/v/vm` - POST <a name="post-v-vm"></a>

Retrieve information about a virtual machine

> **Note**
>
> The calling user needs the `velocity.vm.view` permission on the group owning the VM

**Request:**

```json
{
  "authkey": "<authkey>",
  "vmid": "<VMID>"
}
```

**Response:**

- `200`:

```json
{
  "vmid": "<VMID>",
  "name": "<VM name>",
  "type": "<EFI/...>",
  "state": "<VM state>",

  "cpus": "<Amount of CPUs assigned>",
  "memory_mib": "<Memory size in MiB>",

  "displays": [
    {
      "name": "<Friendly name>",
      "width": "<Screen width>",
      "height": "<Screen height>",
      "ppi": "<Pixels per inch>"
    }
  ],
  "media": [
    {
      "mid": "<MID>",
      "mode": "<USB / BLOCK / VIRTIO>",
      "readonly": true
    }
  ],
  "nics": [
    {
      "type": "<NAT / BRIDGE>",
      "host": "<Host NICID (BRIDGE only)>"
    }
  ],

  "rosetta": true,
  "autostart": true
}
```

- `404 - Not Found`: The `VMID` couldn't be found or the user lacks permissions to view the vm

# `/v/vm/efi` - PUT <a name="put-v-vm-efi"></a>

Create a new virtual machineCreate a new `EFI` virtual machine using the supplied data

> **Note**
>
> The calling user needs the `velocity.vm.create` permission on the target group

**Request:**

```json
{
  "name": "<VM name>",
  "gid": "<GID>",

  "cpus": "<Amount of CPUs assigned>",
  "memory_mib": "<Memory size in MiB>",
  "displays": [
    {
      "name": "<Friendly name>",
      "width": "<Screen width>",
      "height": "<Screen height>",
      "ppi": "<Pixels per inch>"
    }
  ],
  "media": [
    {
      "mid": "<MID>",
      "mode": "<USB / BLOCK / VIRTIO>",
      "readonly": true
    }
  ],
  "nics": [
    {
      "type": "<NAT / BRIDGE>",
      "host": "<Host NICID (BRIDGE only)>"
    }
  ],

  "rosetta": true,
  "autostart": true
}
```

**Field descriptions:**

- `name`: A unique name in the group to identify this virtual machine

- `gid`: The group this vm belongs to

- `cpus`: The amount of virtual CPUs that should be available to the guest

- `memory_mib`: The amount of memory assigned to the guest in `MiB`

- `displays`: An array of displays

  - `description`: A way if identifying this display

  - `width`: The width in `px`

  - `height`: The height in `px`

- `media`: An array of attached media devices

  - `mid`: The `MID` of the media to attach

  - `mode`: The mode the device should use:

    - `USB`: The media is attached via `USB`

    - `BLOCK`: The `VZVirtioBlockDeviceConfiguration` is used to emulate a block device

    - `VIRTIO`: Use `VirtIO` for device attachment

  - `readonly`: Block writing to the media, if not already blocked by other rules

- `nics`: An array of attached [network devices](#nic-info)

  - `type` The type of `NIC`:

    - `NAT`: Use a `NAT`

    - `BRIDGE`: Bridge a host network device

  - `host`: (only needed when `BRIDGE`): The host device to bridge (`NICID`)

- `rosetta`: Whether to enable the rosetta `x86` translation layer if available on the host

- `autostart`: Whether to automatically start this virtual machine on Velocity startup

**Response:**

- `200`: Virtual machine created

```json
{
  "vmid": "<VMID>"
}
```

- `401 - Unauthorized`: The calling user lacks permissions

- `404 - Not Found`: A linked resource couldn't be found

- `406 - Not Acceptable`: There was a quota violation or invalid `type` or `mode` specified

- `409 - Conflict`: A virtual machine in this group with the same name does already exist

# `/v/vm/state` - POST <a name="post-v-vm-state"></a>

Request the current vm [state](#vm-states)

> **Note**
>
> The calling user needs the `velocity.vm.view` permission on the group the vm belongs to

**Request:**

```json
{
  "vmid": "<VMID>"
}
```

**Response:**

- `200`:

```json
{
  "vmid": "<VMID>",
  "state": "<VM state>"
}
```

- `403 - Forbidden`: The calling user lacks permissions

- `404 - Not Found`: The `VMID` is not available or doesn't exist

# `/v/vm/state` - PUT <a name="put-v-vm-state"></a>

Request a [state change](#vm-states) for the virtual machine. Valid states:

- `STOPPED`

- `RUNNING`

- `PAUSED`

> **Note**
>
> The calling user needs the `velocity.vm.state` permission on the group the vm belongs to

**Request:**

```json
{
  "vmid": "<VMID>",
  "state": "<VM state>",
  "force": true
}
```

If the `force` flag is set to `true` state changes will be forceful (eg. shutdown being immediate instead of graceful)

**Response:**

- `200`: State changed. If the VM is already in the requested state, `200` will be used.

```json
{
  "vmid": "<VMID>",
  "state": "<VM state>"
}
```

- `403 - Forbidden`: The calling user lacks permissions

- `404 - Not Found`: The `VMID` is not available to the user or doesn't exist

- `500 - Internal Server Error`: A hypervisor error occured during state transition

# NIC management <a name="v-nic"></a>

# `/v/nic/list` - POST <a name="post-v-nic-list"></a>

List all available host `NICs` available for `BRIDGE` use

> **Note**
>
> The calling user needs the `velocity.nic.list` permission somewhere

**Request:**

```json
<NO BODY>
```

**Response:**

```json
{
  "host_nics": [
    {
      "nicid": "<NICID>",
      "description": "<Host OS description>",
      "identifier": "<Host OS identifier>"
    }
  ]
}
```
