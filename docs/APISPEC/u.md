# User and group management: `/u` <a name="namespace-u"></a>

Velocity's concept of users and groups is similar to that of Unix. Permissions, vm and data pools are always connected to groups due to them being able to be shared across users with a fair amount of granularity.

There is one special group and user with the `UID` / `GID` set to `0`. These are the super user / group that have full access to everything.

### User

Each user is identified by its unique `UID`, its username and password.

Every user automatically gets assigned to a group using the users `username` and the `gid = uid`. This limits the `uid` to a specific range from `0` to something fixed in the server's configuration.

### Group

There are 2 types of groups:

- User groups

- General groups

**User groups**

These groups are the ones that get created upon user creation and reach from `0` to a fixed limit (here called `MAX_UID`). This limit can not be surpassed and thus limits the user count for a Velocity instance.

**General groups**

There are other groups that are not tied to a specific user. These group ids start from `MAX_UID+1` and go up to the maximum value of the used data type.

Each group has a parent group. There is one notable exception: `supergroups`. They don't have a parent group and can only be created by other supergroups. This allows building a hierarchy in the userbase. Each group cannot surpass the quotas of the parent group which allows users to create groups within their groups to split VMs.

### Available endpoints

Authentication:

- [`/u/auth` - POST](#post-u-auth): Authenticate as a user

- [`/u/auth` - DELETE](#delete-u-auth): Log out the current user

- [`/u/auth` - PATCH](#patch-u-auth): Reauthenticate

User and group management:

- [`/u/user` - PUT](#put-u-user): Create a new user

- [`/u/user` - DELETE](#delete-u-user): Remove a user

- [`/u/user/groups` - GET](#get-u-user-groups): Get the groups the user is a member of

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

- `403 - Forbidden`: Tried to renew a non-existing / expired authkey

## `/u/user` - PUT <a name="put-u-user"></a>

> **Note**
> 
> Only users that have the `usermanager` permission for the group can create new users in a group.

This call automatically creates a new group with the groupname set to `<username>` and assigns the new user to that. The `parentgroup` field indicates the parent group's `gid` for the user's group, which cannot be `null`. User groups can't be `supergroups`.

**Request:**

```json
{
  "authkey": "<authkey>",
  "username": "<username>",
  "password": "<password>",
  "parentgroup": "<GID>"
}
```

**Response:**

- `200`: User created

```json
{
  "uid": "<UID>",
  "username": "<username>"
}
```

- `403 - Forbidden`: The current user is not allowed to create new users

- `406 Not Acceptable`: The user creation process tried to create a `supergroup`.

- `409 - Conflict`: A user with the supplied `username` does already exist

## `/u/user` - DELETE <a name="delete-u-user"></a>

> **Note**
> 
> Only users that have the `usermanager` permission for the user's parent group can remove users.

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

## `/u/user/groups` - GET <a id="get-u-user-groups"></a>

Retrieve the groups a user is member of. The `authkey` is used to infer the user. A user that has the `usermanager` permission on a parent group can specify the `uid` field and retrieve group membership information of other users.

**Request:**

```json
{
    "authkey": "<authkey>"
    "uid": "<UID>"
}
```

The `uid` field is optional and allows `usermanagers` to look up group membership of other users

**Response:**

- `200`

```json
{
  "uid": "<UID>",
  "groups": [
    {
      "gid": "<GID>",
      "groupname": "<groupname>",
      "parentgroup": "<GID>"
    }
  ]
}
```

- `403 - Forbidden`: The current user is not allowed to see other users group membership (`usermanager`)

- `404 - Not Found`: No user with the supplied `uid` has been found

## `/u/group` - PUT <a id="put-u-group"></a>

> **Note**
> 
> Only users that are in another supergroup can create `supergroups`

**Request:**

```json
{
  "authkey": "<authkey>",
  "groupname": "<groupname>",
  "parentgroup": "<GID>"
}
```

**Response:**

- `200`: Group created

```json
{
  "gid": "<GID>",
  "groupname": "<groupname>",
  "parentgroup": "<GID>"
}
```

- `403 - Forbidden`: The current user is not allowed to create `supergroups` (`gid = 0` required)

- `409 - Conflict`: A group with the supplied `groupname` does already exist

## `/u/group` - DELETE <a name="delete-u-group"></a>

> **Note**
> 
> Only users that are in the another supergroup can remove `supergroups`

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

- `403 - Forbidden`: The current user is not allowed to remove `supergroups`

## `/u/group/assign` - PUT <a id="put-u-group-assign"></a>

Assign a user to groups:

> **Note**
> 
> A user cannot assign other users to higher groups than its own. He needs the `usermanager` permission for the group to assign to.

**Request:**

```json
{
  "authkey": "<authkey>",
  "uid": "<UID>",
  "group": "<GID>",
  "usermanager": true
}
```

**Response:**

- `200`: Group membership added

```json
{
  "uid": "<UID>",
  "group": "<GID>",
  "usermanager": true
}
```

The response lets the caller know which groups the user now belongs to.

- `403 - Forbidden`: The user tried to assign to a higher group or does not have the required permissions

- `404 - Not Found`: The `uid` of the user to assign has not been found

## `/u/group/assign` - DELETE <a name="delete-u-group-assign"></a>

Remove a user from a group

> **Note**
> 
> Only users that have the `usermanager` permission for the target group can do this

**Request:**

```json
{
  "authkey": "<authkey>",
  "uid": "<UID>",
  "group": "<GID>"
}
```

**Response:**

- `200`: User removed from group

```json
{
  "uid": "<UID>",
  "groups": ["<GID>"]
}
```

The response lets the caller know which groups the user now belongs to.

- `403 - Forbidden`: The current user is not allowed to remove from groups (`usermanager` permission)

- `404 - Not Found`: The `uid` of the user to remove has not been found
