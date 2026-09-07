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

## Artwork

Discovery and detail responses (`GET /api/json/huddlz/:id`) include the read-only
`attributes.image_url` field by default. It is an absolute URL for the current
huddl thumbnail, falling back to the current group thumbnail, or `null` when
neither has artwork. Soft-deleted images are excluded. This uses the same
artwork selection as the website; clients do not need to fetch the group or
reimplement the fallback.

For sparse responses, include `image_url` explicitly:

```text
/api/json/huddlz?date_filter=upcoming&sort=starts_at&fields[huddl]=title,image_url
/api/json/huddlz/:id?fields[huddl]=title,image_url
```

`thumbnail_url` remains a separate legacy stored value and is not the uploaded
artwork source. The internal `display_image_url` and `current_image_url` paths
remain unavailable as public API fields.

iOS clients should decode `image_url` as optional and use it in both discovery
and details, retaining their placeholder when it is null or fails to download.
Resource visibility rules still apply to requests for artwork. Production URLs
use the configured storage host; local URLs use the configured application
origin. A physical device needs an origin it can reach instead of `localhost`.
After deployment, verify both response types and download their returned URLs
before checking live imagery in the iOS app (huddlz-hq/huddlz-ios#7).

## Migrating from the previously advertised contract

The `soonest` and `newest` API values advertised before issue #422 are removed.
Use `sort=starts_at` and `sort=-inserted_at`, respectively. Clients that omitted
`sort` as a workaround can continue doing so without changes. The web discovery
UI retains its Soonest/Newest labels and URLs.

The shared search action also uses native field sorting in GraphQL, for example
`searchHuddlz(sort: [{field: INSERTED_AT, order: DESC}])`; the former named sort
argument is removed there too. Elixir callers supply `query: [sort: ...]` instead
of the former positional ordering argument.
