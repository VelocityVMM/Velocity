# Media management

A virtual machine needs media to work with. Velocity attaches media to a group and stores it in pools, giving groups read or write access. Pools cannot be created via the API, but are rather defined by the Velocity host configuration.

The pool id (`mpid`) identifies the pool, but does not hold **any** reference to where the data is stored. This allows for pools to be moved on the filesystem without loosing references to the files. The Velocity administrator is in charge of tracking the pool ids.

> **Warning**
>
> The administrator is in charge of keeping the `mpid` stable between restarts and configuration changes, else media references may become invalid

A pool allows groups to access media with two permissions:

- `write`: Write to the media (if it is not read-only)

- `manage`: Create / remove media from this pool

Every piece of media is identified by its media id (`mid`) that is a UUID string and its `type`, which can be anything, but some strings are recommended:

- `ISO`: ISO images for bootable read-only media

- `DISK`: Disk images to use for virtual machine storage devices

- `IPSW`: `macOS` restore / installer images

### Available endpoints

[Pool management](#m-pool)

- [`/m/pool/assign` - PUT](#put-m-pool-assign): Assign permissions on a pool for a group

- [`/m/pool/assign` - DELETE](#delete-m-pool-assign): Revoke a group's permission from the pool

- [`/m/pool/list` - POST](#post-m-pool-list): List available pools

[Media management](#m-media)

- [`/m/media/create` - PUT](#put-m-media-create): Create new media
- [`/m/media/upload` - PUT](#put-m-media-upload): Upload media
- [`/m/media` - DELETE](#delete-m-media): Remove media
- [`/m/media/list` - POST](#post-m-media-list): List available media

# Pool management <a name="m-pool"></a>

# `/m/pool/assign` - PUT <a name="put-m-pool-assign"></a>

Assign a group to a mediapool with permissions

If the group is already assigned to the pool, this call will update the permissions

> **Note**
>
> The calling user needs the `velocity.pool.assign` permission on the target group

**Request:**

```json
{
  "gid": "<GID>",
  "mpid": "<MPID>",
  "quota": "<Quota in Bytes>",
  "write": true,
  "manage": true
}
```

**Response:**

- `200`: OK

- `403 - Forbidden`: The calling user lacks permissions

- `404 - Not Found`: The `gid` or `mpid` has not been found

# `/m/pool/assign` - DELETE <a name="delete-m-pool-assign"></a>

Revoke a group's permissions from a mediapool

> **Note**
>
> The calling user needs the `velocity.pool.revoke` permission on the target group

**Request:**

```json
{
  "gid": "<GID>",
  "mpid": "<MPID>"
}
```

**Response:**

- `200`: OK

- `403 - Forbidden`: The calling user lacks permissions

- `404 - Not Found`: The `gid` or `mpid` has not been found

# `/m/pool/list` - POST <a name="post-m-pool-list"></a>

List back available pools for a group

> **Note**
>
> The calling user needs the `velocity.pool.list` permission on the target group

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
  "pools": [
    {
      "mpid": "<MPID>",
      "name": "<Pool name>",
      "write": true,
      "manage": true
    }
  ]
}
```

- `403 - Forbidden`: The calling user lacks permissions

- `404 - Not Found`: The `gid` has not been found

# Media management <a name="m-media"></a>

# `/m/media/create` - PUT <a name="put-m-media-create"></a>

Allocate new media on a pool (`pid`) owned by a group (`gid`)

> **Note**
>
> The calling user needs the `velocity.media.create` permission on the target group

**Request:**

```json
{
  "mpid": "<MPID>",
  "gid": "<GID>",
  "name": "<Media name>",
  "type": "<Media type>",
  "size": "<Size in Bytes>"
}
```

**Response:**

- `200`: Media created

```json
{
  "mid": "<MID>",
  "size": "<Size in Bytes>"
}
```

- `403 - Forbidden`: The calling user lacks permissions or the group does not have the `manage` permission on the pool

- `404 - Not Found`: The `gid` or `pid` has not been found

- `406 - Not Acceptable`: Some quota has been surpassed

- `409 - Conflict`: A file with the same `name` does already exist in this pool

# `/m/media/upload` - PUT <a name="put-m-media-upload"></a>

In contrast to the whole rest of the Velocity API, uploads are handled uniquely: Using HTTP headers to describe and authenticate the upload.

**Request:**

- `HTTP` Additional HTTP Headers:

  - `Content-Length`: The amount of bytes to be submitted. The server will not accept any more bytes than specified here

  - `x-velocity-mpid`: The mediapool id (`MPID`)

  - `x-velocity-gid`: The group id (`GID`)

  - `x-velocity-name`: The name of the file

  - `x-velocity-type`: The type of file

  - `x-velocity-readonly`: If the file should be read only or not (`true` or `false`)

- `body`: The binary data for the file

**Response:**

- `200`: Media uploaded

```json
{
  "mid": "<MID>",
  "size": "<Size in Bytes>"
}
```

- `400 - Bad Request`: The http header is missing required fields

- `403 - Forbidden`: The calling user lacks permissions or the group does not have the `manage` permission on the pool

- `404 - Not Found`: The `gid` or `pid` has not been found

- `406 - Not Acceptable`: Some quota has been surpassed

- `413 - Payload Too Large`: The promised `Content-Length` has been surpassed

# `/m/media` - DELETE <a name="delete-m-media"></a>

Remove media (delete it)

> **Note**
>
> The calling user needs the `velocity.media.remove` permission

**Request:**

```json
{
  "mid": "<MID>"
}
```

**Response:**

- `200`: Media removed

- `403 - Forbidden`: The calling user lacks permissions

- `404 - Not Found`: The `mid` has not been found

# `/m/media/list` - POST <a name="post-m-media-list"></a>

List back available media to a group

> **Note**
>
> The calling user needs the `velocity.media.list` permission on the target group

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
  "media": [
    {
      "mid": "<MID>",
      "mpid": "<MPID>",
      "name": "<Media name>",
      "type": "<Media type>",
      "size": "<Size in Bytes>",
      "readonly": true
    }
  ]
}
```

The `readonly` flag is also true if the group does not have the `write` permission on the pool

- `403 - Forbidden`: THe calling user lacks permissions

- `404 - Not Found`: The `gid` has not been found
