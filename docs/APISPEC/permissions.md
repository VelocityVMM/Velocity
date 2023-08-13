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

# group (`velocity.group`)

Group management

## create (`velocity.group.create`)

Create a new subgroup to the group

## remove (`velocity.group.remove`)

Remove a subgroup

# vm (`velocity.vm`)

Virtual machine controls

## create (`velocity.vm.create`)

Create new virtual machines in the group using up system (and group) quotas.

## remove (`velocity.vm.remove`)

Remove a virtual machine from the assigned group

## alter (`velocity.vm.alter`)

Alter virtual machine attributes and quota usage (RAM, CPU, DISK...)

## view (`velocity.vm.view`)

View the virtual machine and statistics

## interact (`velocity.vm.interact`)

Interact with the virtual machine (RFB, SSH...)

## state (`velocity.vm.state`)

Alter the virtual machine state (start, stop, pause...)

## move (`velocity.vm.move`)

Move a virtual machine to and from the group

> **Note**
> 
> The user moving a virtual machine has to have the `move` permission on both, the source and target group

# pool (`velocity.pool`)

Pool sharing and usage

## create (`velocity.pool.create`)

Create a pool in a group

## remove (`velocity.pool.remove`)

Remove a pool from the group (delete all media and the pool)

## view (`velocity.pool.view`)

View the pools in a group

## media.create (`velocity.pool.media.create`)

Create media in a pool

## media.remove (`velocity.pool.media.remove`)

Remove media from a pool (delete it)

## media.view (`velocity.pool.media.view`)

View media in the pool

## media.read (`velocity.pool.media.read`)

Read from the pool's media

## media.write (`velocity.pool.media.write`)

Write to the pool's media
