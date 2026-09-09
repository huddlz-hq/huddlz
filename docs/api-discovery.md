# Discovery API

Anonymous clients can discover public huddlz with `GET /api/json/huddlz`.

## Private profile and home search defaults

Authenticated clients can read their current private profile with
`GET /api/json/profile`, using `Authorization: Bearer <JWT-or-API-key>`.
This Ash action returns a JSON object directly, without a JSON:API `data`
envelope:

```json
{
  "id": "00000000-0000-0000-0000-000000000001",
  "display_name": "Alex",
  "email": "alex@example.com",
  "search_defaults": {
    "home_location": {
      "label": "Austin, TX",
      "latitude": 30.2672,
      "longitude": -97.7431,
      "time_zone": "America/Chicago"
    },
    "distance_miles": 25
  }
}
```

The endpoint accepts no member ID and reads only the authenticated member's
current profile. Anonymous requests receive 403; invalid credentials receive
401. These fields are not added to public profiles. The existing
`/api/auth/me` identity response remains supported.

`home_location` is `null` when unset, cleared, missing either coordinate, or
missing a valid canonical IANA time zone. Its `label` may be null even when
the coordinates and time zone are usable; clients can identify that area by
its coordinates. There is no persisted radius preference: `distance_miles`
is the application's 25-mile default (search supports 5–100 miles).

Client location selection should follow this order:

1. Use an explicit place or an explicit "everywhere" choice for this search.
2. Otherwise, use the profile's usable home search location.
3. Otherwise, omit both coordinates and clearly indicate an unrestricted search.

For a geographic search, map `latitude`, `longitude`, and `time_zone` to
`search_latitude`, `search_longitude`, and `search_time_zone`, and send
`distance_miles`. For example:

```text
/api/json/huddlz?date_filter=upcoming&search_latitude=30.2672&search_longitude=-97.7431&distance_miles=25&search_time_zone=America%2FChicago
```

For "everywhere", omit both coordinates; the search API does not implicitly
apply the profile default. A radius alone does not restrict results. Search
requests do not update the saved home search location.

`this_week` and `this_month` require a canonical IANA `search_time_zone` for
local calendar boundaries. Use the chosen search location's zone, including
when traveling. Without a search location, use the client's local zone (the
browser zone on the website). If unavailable, ask the user to choose a zone
or use `upcoming`, which does not require one. A home search location's zone
is not a general member time-zone preference.

Fetch the profile again at the start of a subsequent session, or when the
member refreshes their preferences. Each request reads current saved values;
existing credentials continue to work after a location change. Avoid keeping
a separate permanent home preference in the client.

The generated contract is available at `/api/json/open_api` and
`/api/json/swaggerui`.

## Ordering

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
