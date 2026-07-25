# huddlz MCP server

The huddlz MCP server lets MCP clients discover groups and huddlz, inspect
details, and—when authenticated—make a deliberately limited set of changes as
the authenticated person.

## Protocol and transport

- Endpoint: `https://huddlz.com/mcp`
- Transport: MCP Streamable HTTP
- Protocol version: `2025-11-25`
- Authentication: optional `Authorization: Bearer <credential>`
- Response format: JSON-RPC 2.0 with MCP text content containing JSON

The first release uses stateful MCP sessions. Clients must complete the normal
`initialize` → `notifications/initialized` handshake and send the returned
`MCP-Session-Id` on later requests. Standards-compliant MCP clients do this
automatically.

Streamable HTTP was selected instead of stdio because huddlz is a hosted
service. One remote endpoint works for every client and keeps authorization in
the application. API credentials were selected instead of a new MCP-specific
credential or OAuth flow because they are already revocable, expire, and never
store plaintext secrets. OAuth can be added later without changing the tool
contracts.

## Create an API credential

Public discovery does not require authentication. Create an API credential only
when the client needs private data or write tools.

First sign in through the API:

```sh
curl https://huddlz.com/api/auth/sign_in \
  -H 'Content-Type: application/json' \
  -d '{"email":"you@example.com","password":"your password"}'
```

Use the returned sign-in token to create an expiring API credential:

```sh
curl https://huddlz.com/api/auth/api_keys \
  -X POST \
  -H 'Authorization: Bearer SIGN_IN_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{"expires_in_days":30}'
```

The response contains `id`, `key`, and `expires_at`. Save `key` immediately:
huddlz returns its plaintext value only once and persists only its hash.
`expires_in_days` may be 1–365 and defaults to 30.

List credentials:

```sh
curl https://huddlz.com/api/auth/api_keys \
  -H 'Authorization: Bearer SIGN_IN_TOKEN'
```

Revoke a credential:

```sh
curl https://huddlz.com/api/auth/api_keys/API_KEY_ID \
  -X DELETE \
  -H 'Authorization: Bearer SIGN_IN_TOKEN'
```

Revocation takes effect on the next MCP request, including requests in an
already initialized session.

## Connect Claude Code

Claude Code supports remote Streamable HTTP servers and custom headers:

```sh
claude mcp add --transport http huddlz https://huddlz.com/mcp \
  --header 'Authorization: Bearer YOUR_HUDDLZ_API_KEY'
```

For public discovery only, omit the header:

```sh
claude mcp add --transport http huddlz-public https://huddlz.com/mcp
```

After connecting, useful prompts include:

- “Find public virtual huddlz this month.”
- “Show my upcoming huddlz where I am attending.”
- “Show the details for the group with slug `austin-elixir`.”
- “RSVP me to this huddl.” The client should show the proposed tool call and
  obtain confirmation before sending `confirm: true`.

The official MCP Inspector can also connect to the Streamable HTTP endpoint for
protocol debugging and manual tool calls.

## Available tools

### Public read tools

| Tool | Purpose |
| --- | --- |
| `search_groups` | Search groups visible to the caller |
| `get_group` | Read one visible group by slug |
| `search_huddlz` | Search visible huddlz by text, date window, and format |
| `get_huddl` | Read one visible huddl by ID |

Anonymous callers see public groups and public huddlz. An authenticated group
member can also see private groups and huddlz allowed by the existing Ash
policies. `get_huddl` returns virtual access only when the current actor is
allowed to see it.

### Authenticated read tools

| Tool | Purpose |
| --- | --- |
| `list_my_groups` | List owned, joined, or all relevant groups |
| `list_my_huddlz` | List hosted, attending, or waitlisted huddlz |

### Authenticated write tools

| Tool | Purpose |
| --- | --- |
| `join_group` | Join a public group |
| `leave_group` | Leave a group; owners must transfer ownership first |
| `rsvp_huddl` | RSVP to a visible huddl |
| `join_huddl_waitlist` | Join a full huddl's waitlist |
| `cancel_huddl_rsvp` | Cancel the caller's RSVP or waitlist place |
| `create_group` | Create a group owned by the caller |
| `update_group` | Update a group owned by the caller |
| `delete_group` | Delete a group owned by the caller |
| `create_huddl` | Create one non-recurring huddl in an organized group |
| `update_huddl` | Update an organized huddl |
| `cancel_huddl` | Cancel and delete an organized huddl |

Every write tool requires a boolean `confirm` argument equal to `true`.
Clients should set it only after the person reviews the exact action.
Destructive tools are also marked with MCP's `destructiveHint`.

The first release intentionally excludes ownership transfers, member
administration, image uploads, recurring-series creation, and API-credential
management. These need richer review or binary-input flows and remain available
through existing huddlz surfaces.

## Inputs, outputs, and pagination

Tool input schemas reject unknown properties. IDs use UUID strings, dates use
`YYYY-MM-DD`, and times use `HH:MM` or `HH:MM:SS`. Enumerated fields such as
`event_type` accept only the values advertised by `tools/list`.

List tools accept:

- `limit`: 1–50; defaults to 20.
- `cursor`: the opaque `next_cursor` returned by the preceding call.

List results contain:

```json
{
  "items": [],
  "next_cursor": null,
  "total_count": 0
}
```

Do not parse or construct cursors. Pass them back unchanged. Invalid or expired
cursors return an invalid-parameters error.

Tool execution failures use an MCP result with `isError: true` for expected
authentication, authorization, and not-found outcomes. Invalid input uses the
JSON-RPC invalid-parameters code. Internal errors return neutral copy; server
stack traces and stored credential hashes are never included.

## Rate limits

MCP requests are limited per authenticated person or, for anonymous traffic,
per client IP:

- Authenticated: 120 requests per minute.
- Anonymous: 30 requests per minute.

A limited request returns HTTP `429`, a `Retry-After` header, and a JSON-RPC
error. Clients should wait for the advertised interval instead of retrying in a
tight loop. The limits protect against runaway agents, not normal interactive
use.

## Security guidance

- Treat an API credential like a password. Store it in the MCP client's secret
  configuration, not in prompts, source files, screenshots, or chat messages.
- Use the shortest practical expiry and a separate credential per client.
- Revoke credentials that are lost, unused, or attached to a retired client.
- MCP sessions are bound to the person authenticated during initialization. A
  session ID cannot be reused with another person's credential.
- Browser-origin requests must be same-host to prevent DNS rebinding.
- MCP tools pass the authenticated actor into existing Ash actions. Tool
  arguments cannot choose or impersonate another actor.
- Public versus private visibility, organizer permissions, capacity, RSVP
  rules, and group membership rules remain enforced by the same Ash policies as
  the web app and APIs.

## Troubleshooting

### Authentication required

Confirm the header is exactly `Authorization: Bearer <key>`, the credential has
not expired, and it has not been revoked. API credentials begin with the
huddlz-generated prefix; do not use the credential ID as the key.

### Server not initialized

Use an MCP client that completes both initialization steps. A raw HTTP caller
must send `notifications/initialized` after `initialize` and include the
returned `MCP-Session-Id`.

### Session not found

The server restarted or the session expired. Reconnect so the client performs a
new initialization handshake.

### Forbidden or not found

The same Ash visibility rules used by huddlz may intentionally hide the target.
Check that the authenticated person belongs to the private group or organizes
the group containing the huddl.

### Invalid parameters

Refresh the client's tool list, verify enum values and date/time formats, and
pass pagination cursors back unchanged. Write tools also require
`"confirm": true`.

### Too many requests

Honor `Retry-After`, reduce polling, and use the largest practical page size
instead of repeatedly fetching small pages.

