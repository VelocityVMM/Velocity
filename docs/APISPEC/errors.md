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

**Structure:**

- `<Velocity error> (<http status>)` - `<route> - <method>`: Error description

## `/u`

### `/u/auth`

- `100 (403)` - `/u/auth - POST`: Authentication failed (username or password do not match)

- `101 (403)` - `/u/auth - PATCH`: The old authkey hasn't been found

- `102 (403)` - `/u/auth - PATCH`:The old authkey has expired

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
