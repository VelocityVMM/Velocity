# Velocity API specification `v 1.0`

This is a proposal for the `1.0` version of the Velocity API specification.

The Velocity API uses `JSON` as its language.

### Hierarchy

Velocity manages virtual machines and resources seperately.

For resources, velocity uses so-called "pools" and virtual machines are managed in "catalogs".

The API is divided into several namespaces:

- [`/u`](u.md): User and group management

### Errors

If the API enconters some kind of error, it will respond with a http-response code in a non-200 range and an error as follows:

```json
{
  "code": "<Error code>",
  "message": "<Some error message (optional)>"
}
```

Some additional fields may be added to the error response depending on calls but this layout is guaranteed.

Some http-response codes are fixed:

- `400 - Bad Request`: The request is missing fields

- `401 - Unauthorized`: The request is missing the `authkey` for privileged actions

- `500 - Internal Server Error`: The server encountered an error while processing the request
