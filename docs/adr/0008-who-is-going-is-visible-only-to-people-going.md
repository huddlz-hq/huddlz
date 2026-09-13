# Who's going is visible only to people who are going

A huddl page shows the people going to it only to people who are going themselves: anyone with an RSVP or a waitlist spot on that huddl. Everyone else who can open the huddl sees the count. The same rule governs the attendee list on the API. There is no exception for group members, for the group's owner and organizers, or for platform administrators (ADR-0004). Creating a huddl RSVPs its creator, so the person who scheduled it is going, and sees the list, until they cancel.

We want as much privacy for people on huddlz as the product allows. Seeing that someone is going is the kind of fact people expect to share with the room they are joining, not with everyone who can find the huddl.

## Considered options

- **Group members plus attendees.** Members can already see the group's roster, so this would reveal RSVP intent only. Rejected: it is a wider audience than the room, and the roster is a different promise (who belongs) than the list (who is coming to this).
- **Anyone signed in, for public huddlz.** Rejected: it turns an RSVP into a public statement.
- **An exception for organizers who are not going.** Rejected: every organizer job is served without names. Capacity, the waitlist and turnout are counts; promotion from the waitlist is automatic; problem people are handled at the group level, where organizers see the roster and can remove anyone. An organizer who wants the list RSVPs, which is honest, since it means they are coming.

## Consequences

The organize workspace is a different surface with different rules. Its activity feed keeps naming the people who RSVPd, joined a waitlist or got a spot, because an organizer who is not attending may still need to act there for another organizer. That is the one place an organizer learns who is going without going.

After a huddl ends the list is still the people who RSVPd, never who came: turnout is a count (ADR-0003). Copy on the page says "RSVPd", not "attended".

The waitlist itself stays a count for everyone but organizers, whose operational view of it is unchanged.
