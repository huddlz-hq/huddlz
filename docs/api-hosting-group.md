# Hosting group API

Clients can identify the group hosting a huddl through the read-only `group`
relationship. Existing huddl and group visibility rules apply independently,
using the request's authenticated viewer (or anonymous access).

## GraphQL

Send this query to `POST /gql` with the huddl ID in the `id` variable:

```graphql
query HuddlDetail($id: ID!) {
  getHuddl(id: $id) {
    id
    title
    group {
      id
      name
      slug
    }
  }
}
```

`Huddl.group` is a nullable `Group`. Its existing public fields are selectable;
`name` is enough to display the host, and `slug` supports linking to the group.
The relationship is also selectable on huddlz returned by list queries.

## JSON:API

Request the relationship explicitly to fetch the huddl and group together:

```http
GET /api/json/huddlz/:id?include=group&fields[group]=name,slug
```

The response's `data.relationships.group.data` contains the group's `type`
(`group`) and `id`. Match these to the group resource in the top-level `included`
array, where `attributes.name` and `attributes.slug` contain its display name
and slug. The same include works on huddl list endpoints. Omitting
`fields[group]` requests the group's existing public fields.

Without `include=group`, the response does not embed the group or provide its
name. Clients must not interpret an unrequested relationship as an unavailable
host.

## Unavailable hosts

A viewer may be allowed to see a huddl without being allowed to see its group.
For example, a former member with RSVP history can still see a cancelled huddl
in a private group.

In that case, the requested relationship is `group: null` in GraphQL and
`relationships.group.data: null` in JSON:API, with no included group. The huddl
remains in the response. Clients can display "Host unavailable" without
inferring why the group is unavailable. Unexpected request failures remain
errors.

If the viewer cannot read the huddl itself, the existing inaccessible-huddl
response still applies. Including its group does not grant access.

The raw `group_id` / `groupId` field is private. The relationship does not expose
group owners' accounts, membership records, or invitations, and does not add
relationship mutation endpoints.
