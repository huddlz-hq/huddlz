# Attendance API

Authenticate with a bearer JWT or API key. Attendance operations act on the
current caller and preserve the website's huddl visibility, lifecycle, and
capacity rules.

| Operation | JSON:API | GraphQL mutation |
| --- | --- | --- |
| RSVP | `PATCH /api/json/huddlz/:id/rsvp` | `rsvpToHuddl(id: ID!)` |
| Join a full huddl's waitlist | `PATCH /api/json/huddlz/:id/join_waitlist` | `joinHuddlWaitlist(id: ID!)` |
| Cancel RSVP or leave waitlist | `PATCH /api/json/huddlz/:id/cancel_rsvp` | `cancelRsvpToHuddl(id: ID!)` |

JSON:API requests use `Content-Type: application/vnd.api+json` and this body:

```json
{"data":{"type":"huddl","id":"HUDDL_ID","attributes":{}}}
```

The returned huddl includes `data.attributes.attendance_state` by default.
When using sparse fieldsets, request `attendance_state` explicitly. GraphQL
clients select `attendanceState` on the result:

```graphql
mutation JoinWaitlist($id: ID!) {
  joinHuddlWaitlist(id: $id) {
    result { id attendanceState }
    errors { message }
  }
}
```

`attendance_state` / `attendanceState` describes the current caller's recorded
attendance: `none`, `waitlisted`, or `confirmed`. It is also available when
reading huddlz; anonymous callers receive `none`. It does not expose anyone
else's attendance or a waitlist position.

Check API errors before interpreting the returned state. A successful RSVP
can return `waitlisted` when the caller already has a waitlist entry. Repeated
waitlist requests do not create duplicate attendance. A confirmed caller who
requests the waitlist of a full huddl remains `confirmed`. Joining the waitlist
fails when seats are available or capacity is unlimited; use RSVP instead.
Unavailable or unauthorized huddlz remain failures.
