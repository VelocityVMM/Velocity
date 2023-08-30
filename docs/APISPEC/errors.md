# Errors

This is an exhaustive list of error codes that can be returned by the Velocity API.

**Structure:**

- `<Velocity error> (<http status>)` - `<route> - <method>`: Error description

## `/u`

### `/u/auth`

- `100 (403)` - `/u/auth - POST`: Authentication failed (username or password do not match)

- `101 (403)` - `/u/auth - PATCH`: The old authkey hasn't been found

- `102 (403)` - `/u/auth - PATCH`:The old authkey has expired


