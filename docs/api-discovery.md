# Discovery API

Anonymous clients can discover public huddlz with `GET /api/json/huddlz`.

The `sort` query parameter uses standard JSON:API field sorting. Fields sort
ascending unless prefixed with `-`; comma-separated fields are applied in order.

| UI label | API value | Ordering |
| --- | --- | --- |
| Soonest | `starts_at` | Start time ascending |
| Newest | `-inserted_at` | Creation time descending |

For example: `/api/json/huddlz?date_filter=upcoming&sort=-inserted_at&page[limit]=20`.
The creation timestamp is named `inserted_at`, not `created_at`, and is a public,
read-only field.

Omitting `sort` defaults to start time ascending. Explicit sorts replace that
default. For example, `sort=-starts_at` puts the latest start first, and
`sort=starts_at,-inserted_at` orders matching start times by creation time
descending. Ordering is applied before pagination.

The date filter controls which huddlz are included; sorting only controls their
sequence. See `/api/json/open_api` or `/api/json/swaggerui` for supported fields.

## Migrating from the previously advertised contract

The `soonest` and `newest` API values advertised before issue #422 are removed.
Use `sort=starts_at` and `sort=-inserted_at`, respectively. Clients that omitted
`sort` as a workaround can continue doing so without changes. The web discovery
UI retains its Soonest/Newest labels and URLs.

The shared search action also uses native field sorting in GraphQL, for example
`searchHuddlz(sort: [{field: INSERTED_AT, order: DESC}])`; the former named sort
argument is removed there too. Elixir callers supply `query: [sort: ...]` instead
of the former positional ordering argument.
