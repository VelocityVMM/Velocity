# User and group management: `/u` <a name="namespace-u"></a>

Velocity's concept of users and groups is similar to that of Unix. Permissions, vm and data pools are always connected to groups due to them being able to be shared across users with a fair amount of granularity.

There is one special group  `GID` set to `0`. This is the supergroup that has full access to everything. All other groups descend from that group and get delegated. This group's parent gid is set to `0`, creating a recursion to signal the root group.

### User

Each user is identified by its unique `UID`, its username and password.

### Group

Each group has a parent group and can inherit some of the parent group's quotas, but never surpass them.

### Available endpoints

Authentication:

- [`/u/auth` - POST](#post-u-auth): Authenticate as a user

- [`/u/auth` - DELETE](#delete-u-auth): Log out the current user

- [`/u/auth` - PATCH](#patch-u-auth): Reauthenticate

User and group management:

- [`/u/user` - POST](#post-u-user): Retrieve user information

- [`/u/user` - PUT](#put-u-user): Create a new user

- [`/u/user` - DELETE](#delete-u-user): Remove a user

- [`/u/group` - PUT](#put-u-group): Create a new group

- [`/u/group` - DELETE](#delete-u-group): Remove a group

- [`/u/group/assign` - PUT](#put-u-group-assign): Assign a user to a group / add permissions

- [`/u/group/assign` - DELETE](#delete-u-group-assign): Remove group membership / remove permissions

## `/u/auth` - POST <a name="post-u-auth"></a>

Velocity's authentication model works using so-called 'authkeys'. Every user that is currently authenticated gets such a key that has a certain validity window. Every privileged action that requires authentication requires this authkey to be sent with the request. To obtain such an authkey, a user can issue an authentication to this endpoint.

**Request:**

```json
{
  "name": "<username>",
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
> This will immediately drop the old authkey in favor of the newly generated one

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

- `403 - Forbidden`: Tried to renew a non-existing / expired authkey

## `/u/user` - POST <a name="post-u-user"></a>

Retrieve information about the current user. The `authkey` is used to infer the user. There is no possibility to retrieve information about other users.

**Request:**

```json
{
    "authkey": "<authkey>"
}
```

**Response:**

- `200`

```json
{
    "uid": "<UID>",
    "name": "<User name>",
    "memberships": [
        {
            "gid": "<GID>",
            "parent_gid": "<GID>",
            "name": "<Group name>",
            "permissions": [
                {
                    "pid": "<PID>",
                    "name": "<Permission name>",
                    "description": "<Permission description>"
                }
            ]
        }
    ]
}
```

## `/u/user` - PUT <a name="put-u-user"></a>

Create a new user

> **Note**
> 
> Only users that have the `velocity.user.create` permission

**Request:**

```json
{
  "authkey": "<authkey>",
  "name": "<username>",
  "password": "<password>"
}
```

**Response:**

- `200`: User created

```json
{
  "uid": "<UID>",
  "name": "<username>"
}
```

- `403 - Forbidden`: The current user is not allowed to create new users

- `409 - Conflict`: A user with the supplied `username` does already exist

## `/u/user` - DELETE <a name="delete-u-user"></a>

> **Note**
> 
> Only users that have the `velocity.user.remove` permission for the user's parent group can remove users

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

Create a new group. There cannot be duplicate group names in a parent group.

> **Note**
> 
> The user needs the `velocity.group.create` permission on the parent group

**Request:**

```json
{
  "authkey": "<authkey>",
  "name": "<groupname>",
  "parent_gid": "<GID>"
}
```

**Response:**

- `200`: Group created

```json
{
  "gid": "<GID>",
  "name": "<groupname>",
  "parent_gid": "<GID>"
}
```

- `403 - Forbidden`: The calling user lacks permissions

- `409 - Conflict`: A group with the supplied `groupname` within the parent group does already exist

## `/u/group` - DELETE <a name="delete-u-group"></a>

Remove a group from a parent group

> **Note**
> 
> The user needs the `velocity.group.remove` permission on the parent group

This call removes all the VMs and images owned by this group.

**Request:**

```json
{
  "authkey": "<authkey>",
  "gid": "<GID>"
}
```

**Response:**

- `200`: Group removed

- `403 - Forbidden`: The calling user lacks permissions

## `/u/group/assign` - PUT <a id="put-u-group-assign"></a>

Assign a user to groups or add permissions.

> **Note**
> 
> A user cannot assign other users to higher groups than its own. He needs the `velocity.user.assign` permission for the group to assign to

> **Note**
> 
> A user can only forward permissions itself has. If the user tries to give permissions to another user that it doesn't have, this call will fail

**Request:**

```json
{
  "authkey": "<authkey>",
  "uid": "<UID>",
  "group": "<GID>",
  "permissions": ["<permission>"]
}
```

The permissions array lists the permissions that the user should receive.

**Response:**

- `200`: Group membership added

```json
{
  "uid": "<UID>",
  "group": "<GID>",
  "permissions": ["<permission>"]
}
```

The response lets the caller know which groups the user now belongs to.

- `403 - Forbidden`: The user tried to assign to a higher group, higher permissions or does not have the required permissions

- `404 - Not Found`: The `uid` of the user to assign has not been found

## `/u/group/assign` - DELETE <a name="delete-u-group-assign"></a>

Remove a user from a group

> **Note**
> 
> Only users that have the `velocity.user.revoke` permission for the target group can do this

**Request:**

```json
{
  "authkey": "<authkey>",
  "uid": "<UID>",
  "group": "<GID>",
  "permissions": ["<permission>"]
}
```

The `permissions` field is optional. If it is set, this will remove the listed permissions on the target group if available. If this field is omitted, this will remove the user completely, revoking all permissions.

**Response:**

- `200`: User removed from group

```json
{
  "uid": "<UID>",
}
```

- `403 - Forbidden`: The current user is not allowed to remove from groups (`usermanager` permission)

- `404 - Not Found`: The `uid` of the user to remove has not been found
