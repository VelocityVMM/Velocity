# User and group management: `/u` <a name="namespace-u"></a>

Velocity's concept of users and groups is similar to that of Unix. Permissions, vm and data pools are always connected to groups due to them being able to be shared across users with a fair amount of granularity.

There is one special group `GID` set to `0`. This is the supergroup that has full access to everything. All other groups descend from that group and get delegated. This group's parent gid is set to `0`, creating a recursion to signal the root group.

### User

Each user is identified by its unique `UID`, its username and password.

### Group

Each group has a parent group and can inherit some of the parent group's quotas, but never surpass them.

### Permission

A user can be assigned to a group with permissions. These permissions will be inherited to subgroups: When a user has a permission on a group, it also applies to all of its subgroups.

### Available endpoints

[Authentication](#u-auth)

- [`/u/auth` - POST](#post-u-auth): Authenticate as a user

- [`/u/auth` - DELETE](#delete-u-auth): Log out the current user

- [`/u/auth` - PATCH](#patch-u-auth): Reauthenticate

[User management](#u-user)

- [`/u/user` - POST](#post-u-user): Retrieve user information

- [`/u/user` - PUT](#put-u-user): Create a new user

- [`/u/user` - DELETE](#delete-u-user): Remove a user

- [`/u/user/list` - POST](#post-u-user-list): List all users on the velocity system

[Permission management](#u-user-permission)

- [`/u/user/permission` - PUT](#put-u-user-permission): Add new permissions to a user

- [`/u/user/permission` - DELETE](#delete-u-user-permission): Revoke permissions from a user

[Group management](#u-group)

- [`/u/group` - POST](#post-u-group): Retrieve group information

- [`/u/group` - PUT](#put-u-group): Create a new group

- [`/u/group` - DELETE](#delete-u-group): Remove a group

- [`/u/group/list` - POST](#post-u-group-list): List all groups on the velocity system

# Authentication <a name="u-auth"></a>

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

# User management <a name="u-user"></a>

## `/u/user` - POST <a name="post-u-user"></a>

Retrieve information about the current user. The request's `authkey` is used to infer the user, unless the `uid` field is specified.

> **Note**
> 
> To query information about other users, the calling user needs the `velocity.user.view` permission

**Request:**

```json
{
  "uid": "<UID (optional)>"
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

- `403 - Forbidden`: The calling user lacks permissions to view other user's information
- `404 - Not Found`: The desired `uid` hasn't been found

## `/u/user` - PUT <a name="put-u-user"></a>

Create a new user

> **Note**
> 
> Only users that have the `velocity.user.create` permission

**Request:**

```json
{
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
  "uid": "<UID>"
}
```

**Response:**

- `200`: User removed

- `403 - Forbidden`: The current user is not allowed to remove users

- `404 - Not Found`: No user with the supplied `uid` has been found

## `/u/user/list` - POST <a name="post-u-user-list"></a>

List all users on this velocity instance

> **Note**
> 
> The calling user needs the `velocity.user.list` permission

**Request:**

```json
<NO BODY>
```

**Response:**

- `200`

```json
{
  "users": [
    {
      "uid": "<UID>",
      "name": "<username>"
    }
  ]
}
```

- `403 - Forbidden`: The calling user lacks permissions

# Permission management <a name="u-user-permission"></a>

## `/u/user/permission` - PUT <a name="put-u-user-permission"></a>

Put new permissions for a user on a specific group

> **Note**
> 
> A user cannot assign other users to higher groups than its own. He needs the `velocity.user.assign` permission for the group to assign to

> **Note**
> 
> A user can only forward permissions itself has. If the user tries to give permissions to another user that it doesn't have, this call will fail

**Request:**

```json
{
  "uid": "<UID>",
  "gid": "<GID>",
  "permission": "<permission identifier>"
}
```

The permissions array lists the permissions that the user should receive.

**Response:**

- `200`: Permission added

- `403 - Forbidden`: The user tried to assign to a higher group, higher permissions or does not have the required permissions

- `404 - Not Found`: The `uid` or `gid` or permission name has not been found

## `/u/user/permission` - DELETE <a name="delete-u-user-permission"></a>

Remove user permissions

> **Note**
> 
> Only users that have the `velocity.user.revoke` permission for the target group can do this

**Request:**

```json
{
  "uid": "<UID>",
  "gid": "<GID>",
  "permission": "<permission>"
}
```

The `permission` field is optional. If it is set, this will remove the listed permissions on the target group if available. If this field is omitted, this will remove the user completely, revoking all permissions.

**Response:**

- `200`: Permission removed

- `403 - Forbidden`: The current user is not allowed to remove from groups (`velocity.user.revoke` permission) or does not have the removed permission

- `404 - Not Found`: The `uid`, `gid` or permission name has not been found

# Group management <a name="u-group"></a>

## `/u/group` - POST <a id="post-u-group"></a>

Retrieve information about a group

> **Note**
> 
> The calling user needs the `velocity.group.view` permission on the requested group

**Request:**

```json
{
  "gid": "<GID>"
}
```

**Response:**

- `200`

```json
{
  "gid": "<GID>",
  "parent_gid": "<GID>",
  "name": "<Group name>",
  "memberships": [
    {
      "uid": "<UID>",
      "name": "<User name>",
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

- `403 - Forbidden`: The calling user lacks permissions

- `404 - Not Found`: The `gid` could not be found

## `/u/group` - PUT <a id="put-u-group"></a>

Create a new group. There cannot be duplicate group names in a parent group.

> **Note**
> 
> The user needs the `velocity.group.create` permission on the parent group

**Request:**

```json
{
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

- `404 - Not Found`: The `parent_gid` does not exist

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
  "gid": "<GID>"
}
```

**Response:**

- `200`: Group removed

- `403 - Forbidden`: The calling user lacks permissions

- `404 - Not Found`: The `gid` does not exist

## `/u/group/list` - POST <a name="post-u-group-list"></a>

List back all existing groups on this velocity instance

> **Note**
> 
> The calling user needs at least one permission on a group for its name (and subgroups) to be displayed.
> 
> Do note that groups that are essential to recreating the tree will get listed, too

**Request:**

```json
<NO BODY>
```

**Response:**

- `200`

```json
{
  "groups": [
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

The `permissions` field does only list direct permissions (not inherited ones)
