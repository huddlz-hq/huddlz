# Discovery API

Anonymous clients can discover public huddlz with `GET /api/json/huddlz`.

The `sort` query parameter accepts named discovery orderings:

| Value | Ordering |
| --- | --- |
| `soonest` (default) | Start time ascending |
| `newest` | Creation time descending |

For example: `/api/json/huddlz?date_filter=upcoming&sort=soonest&page[limit]=20`.
Omitting `sort` keeps the same soonest-first ordering. The date filter controls
which huddlz are included; ordering only controls their sequence.

This discovery route uses named orderings rather than generic JSON:API field
sorting such as `sort=starts_at` or `sort=-inserted_at`. Other collection routes
retain their documented field sorting. See `/api/json/open_api` or
`/api/json/swaggerui` for the generated contract.

Clients that omitted `sort` to work around issue #422 can continue doing so.
Explicit `sort=soonest` and `sort=newest` now use the same search ordering as
the web discovery UI; no parameter rename is needed.
