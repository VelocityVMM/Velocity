# Pool management

Each virtual machine uses certain resources, most notably storage. To make managing and sharing storage easier, velocity uses pools.

Pools build a hierarchy in the Velocity system. This allows some root pools to be created by the system for splitting up storage on different domains, disks and directories. Each pool has a certain quota assigned to it, which cannot be exceeded by any contents and subpools. The sum of quotas of subpools may be larger than that of the parent pool, but the used amount cannot surpass the quota of **ANY** parent pool.

Every pool is identified by its unique pool-id (`PID`)

Each piece of media is identified by its unique media-id (`MID`)

### Available endpoints:

Pool management:

- [`/p` - GET](#get-p): Retrieve pools available for this group

- [`/p` - PUT](#put-p): Create a new pool in a group

- [`/p` - DELETE](#delete-p): Remove a pool from a group

Pool media management:

- [`/p/media` - GET](#get-p-media): Get available media in this pool

- [`/p/media` - PUT](#put-p-media): Upload or create media

- [`/p/media` - DELETE](#delete-p-media): Remove media

# `/p` - GET <a name="get-p"></a>

Retrieve the pools available for a group

> **Note**
> 
> Only pool shares that have the `velocity.pool.view` permission for the group are listed

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
    "gid": "<GID>",
    "pools": [
        {
            "pid": "<PID>",
            "quota_mib": "<AVAILABLE MiB>",
            "permissions": ["<PERMISSION>"]
        }
    ]
}
```

- `404 - Not Found`: No group with the provided `gid` has been found

# `/p` - PUT <a name="put-p"></a>

Create a new pool in a group

> **Note**
> 
> The creating user needs the `velocity.pool.create` permission

**Request:**

```json
{
    "authkey": "<authkey>",
    "parentpool": "<PID>",
    "name": "<name>",
    "quota_mib": "<AVAILABLE MiB>"
}
```

**Response:**

- `200`: Pool created

```json
{
    "pid": "<PID>"
}
```

- `403 - Forbidden`: The calling user lacks permissions
- `406 - Not Acceptable`: The quota of a parent pool is exceeded
- `409 - Conflict`: A pool with the same name does already exist in the group

# `/p` - DELETE <a name="delete-p"></a>

Removes a pool and **all** of its media from the system

> **Note**
> 
> The calling user needs the `velocity.pool.remove` permission

> **Warning**
> 
> This will immediately and irreversibly drop the media contents and files from the host's disk

**Request:**

```json
{
    "authkey": "<authkey>",
    "pid": "<PID>"
}
```

**Response:**

- `200`: Pool removed

- `403 - Forbidden`: The calling user lacks permissions

- `404 - Not Found`: No pool with the `pid` has been found

# `/p/media` - GET <a name="get-p-media"></a>

Retrieve a list of available media in the pool

> **Note**
> 
> The calling user needs the `velocity.pool.media.view` permission

**Request:**

```json
{
    "authkey": "<authkey>",
    "pid": "<PID>"
}
```

**Response:**

- `200`:

```json
{
    "pid": "<PID>",
    "media": [
        {
            "mid": "<MID>",
            "filename": "<FILE NAME>",
            "size_mib": "<SIZE IN MiB>"
        }
    ]
}
```

- `403 - Forbidden`: The calling user lacks permissions

- `404 - Not Found`: The `pid` couldn't be found

# `/p/media` - PUT <a name="put-p-media"></a>

Upload new media to the pool or create new media

> **Note**
> 
> The uploading user needs the `velocity.pool.media.create` permission

There are 2 variants of this call:

- Create media

- Upload media

## Create media

**Request:**

```json
{
    "authkey": "<authkey>",
    "pid": "<PID>",
    "filename": "<FILE NAME>",
    "size_mib": "<FILE SIZE IN MiB>"
}
```

## Upload media

This is one exception to the JSON-style API. Binary data will be uploaded, so this will use the `PUT` - parameters:

```
/p/media/<authkey>/<pid>/<filename>
```

Fields:

- `authkey`: The authkey that identifies the user

- `pid`: The pool id to put the media into

- `filename`: The filename

**Response:**

- `200`: Media created / uploaded

```json
{
    "pid": "<PID>",
    "filename": "<FILE NAME>",
    "mid": "<MID>"
}
```

- `403 - Forbidden`: The calling user lacks permissions

- `413 - Content Too Large`: The submitted media exceeds a quota

- `409 - Conflict`: Conflicting media exists in this pool (`filename`)

# `/p/media` - DELETE <a name="delete-p-media"></a>

Remove media from the Velocity instance

> **Note**
> 
> The calling user needs the `velocity.pool.media.remove` permission

> **Warning**
> 
> This will immediately and irreversibly drop the media contents and file from the host's disk

**Request:**

```json
{
    "authkey": "<authkey>",
    "mid": "<MID>"
}
```

**Response:**

- `200`: Media removed

- `403 - Forbidden`: The calling user lacks permissions

- `404 - Not Found`: The requested `mid` has not been found
