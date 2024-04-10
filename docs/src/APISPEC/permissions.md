# Permissions

This is an extensive list that lists every permission that is available in the Velocity system.

# velocity

The namespace for all velocity permissions

# user (`velocity.user`)

User management

## create (`velocity.user.create`)

Create new users.

> **Note**
>
> Do keep in mind that this permission allows a user to create new users for the system and thus consume unique usernames!

## remove (`velocity.user.remove`)

Remove users that are in the group from the system.

> **Note**
>
> This destroys users at the system level, if a user should only be able to revoke a user from a group, it should have the `revoke` permission

## assign (`velocity.user.assign`)

Assign new users to the group

## revoke (`velocity.user.revoke`)

Remove users from the group

## view (`velocity.user.view`)

Get user information about other users

## list (`velocity.user.list`)

List all users of the velocity instance

# group (`velocity.group`)

Group management

## create (`velocity.group.create`)

Create a new subgroup to the group

## remove (`velocity.group.remove`)

Remove a subgroup

## view (`velocity.group.view`)

Retrieve information about the group and all of its members an permissions

# pool (`velocity.pool`)

Pool permissions

## list (`velocity.pool.list`)

List pools available to a group

## assign (`velocity.pool.assign`)

Assign a group to a pool

## revoke (`velocity.pool.revoke`)

Revoke a group's permissions from a mediapool

# media (`velocity.media`)

Media permissions

## list (`velocity.media.list`)

List media in a group

## create (`velocity.media.create`)

Create media in a group

## remove (`velocity.media.remove`)

Remove media from a group (delete it)

# vm (`velocity.vm`)

## create (`velocity.vm.create`)

Create a new virtual machine in the group

## remove (`velocity.vm.remove`)

Remove a virtual machine from the group

## alter (`velocity.vm.alter`)

Alter a virtual machine parameters (CPU, RAM...)

## view (`velocity.vm.view`)

View statistics for a virtual machine

## interact (`velocity.vm.interact`)

Interact with a virtual machine (RFB, Serial...)

## state (`velocity.vm.state`)

Alter the virtual machine state (start, stop, pause...)

# nic (`velocity.nic`)

## list (`velocity.nic.list`)

List available host NICs
