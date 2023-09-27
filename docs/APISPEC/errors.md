# Errors

This is an exhaustive list of error codes that can be returned by the Velocity API.

### Codes:

The error codes do have some structure:

The last 2 digits indicate the error:

- `0x` Indicates a permission error

- `1x` Indicates that something hasn't been found

- `2x` Indicates conflicts and not allowable actions

The next digit indicates the method:

- `0`: other codes

- `1`: POST

- `2`: PUT

- `3`: DELETE

- `4`: PATCH

And the others are reserved for the rest (contexts, endpoints, routes, etc...)

**Example:**

If a route has the error id `12` and wants to indicate a permission error on the `PATCH` method, the error code is the following:

```
1230x
```

## General

- `100` > `403`: An authkey is needed for the request but it has expired or does not exist

## `/u`

### `/u/auth`

**POST**

- `1100` > `403`: Authentication failed (username or password do not match)

**PATCH**

- `1400` > `403`: The old authkey hasn't been found

- `1401` > `403`: The old authkey has expired

### `/u/user`

**POST**

- `2100` > `403`: Permission `velocity.user.view` is needed

- `2110` > `404`: User has not been found

**PUT**

- `2200` > `403`: Permission `velocity.user.create` is needed

- `2220` > `409`: A user with the same name exists

**DELETE**

- `2300` > `403`: Permission `velocity.user.remove` is needed

- `2310`> `404`: User has not been found

### `/u/user/list`

**POST**

- `3100` > `403`: Permission `velocity.user.list` is needed

### `/u/user/permission`

**PUT**

- `4200` > `403`: Permission `velocity.user.assign` is needed

- `4210` > `404`: User has not been found

- `4211` > `404`: Group has not been found

- `4212` > `404`: Permission has not been found

- `4220` > `403`: Assigned permission is too high

**DELETE**

- `4300` > `403`: Permission `velocity.user.revoke` is needed

- `4310` > `404`: User has not been found

- `4311` > `404`: Group has not been found

- `4312` > `404`: Permission has not been found

### `/u/group`

**POST**

- `5100` > `403`: Permission `velocity.group.view` is needed

- `5110` > `404`: roup has not been found

**PUT**

- `5200` > `403`: Permission `velocity.group.create` is needed

- `5210` > `404`: Parent group has not been found

- `5220` > `409`: A group with the same name exists within the parent group

**DELETE**

- `5300` > `403`: Permission `velocity.group.remove` is needed

- `5310` > `404`: Group has not been found

### `/m/pool/assign`

**PUT**

- `6200` > `403`: Permission `velocity.pool.assign` is needed

- `6210` > `404`: Group has not been found

- `6211` > `404`: Mediapool has not been found

**DELETE**

- `6300` > `403`: Permission `velocity.pool.revoke` is needed

- `6310` > `404`: Group has not been found

- `6311` > `404`: Mediapool has not been found

### `/m/pool/list`

**POST**

- `7100` > `403`: Permission `velocity.pool.list` is needed

- `7110` > `404`: Group has not been found

### `/m/media/create`

**PUT**

- `8200` > `403`: Permission `velocity.media.create` is needed

- `8201` > `403`: Group does not have the `manage` permission on the media pool

- `8210` > `404`: Group has not been found

- `8211` > `404`: Mediapool has not been found

- `8220` > `409`: The filename is a duplicate

- `8221` > `406`: Some quota has been surpassed

### `/m/media/upload`

**PUT**

- `9200` > `403`: Permission `velocity.media.create` is needed

- `9201` > `403`: Group does not have the `manage` permission on the media pool

- `9210` > `400`: The `Content-Length` header field is missing

- `9211` > `400`: The `x-velocity-authkey` header field is missing

- `9212` > `400`: The `x-velocity-mpid` header field is missing

- `9213` > `400`: The `x-velocity-gid` header field is missing

- `9214` > `400`: The `x-velocity-name` header field is missing

- `9215` > `400`: The `x-velocity-type` header field is missing

- `9216` > `400`: The `x-velocity-readonly` header field is missing

- `9217` > `404`: Group has not been found

- `9218` > `404`: Mediapool has not been found

- `9220` > `409`: The filename is a duplicate

- `9221` > `406`: Some quota has been surpassed

- `9222` > `413`: More bytes than specified in `Content-Length` have been submitted

### `/m/media/list`

**POST**

- `10100` > `403`: Permission `velocity.media.list` is needed

- `10110` > `404`: Group has not been found

### `/v/nic/list`

**POST**

- `11100` > `403`: Permission `velocity.nic.list` is needed
