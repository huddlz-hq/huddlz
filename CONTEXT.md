# huddlz

huddlz helps groups organize and discover gatherings while preserving the local scheduling context of each group and huddl.

## Communities and places

**Group**:
A community that organizes huddlz and has a home location.

**Archived group**:
A reversibly closed group whose memberships and history are preserved for existing members. Archival is distinct from permanent deletion and moderation suspension.
_Avoid_: Deleted group, suspended group

**Group restoration**:
The reopening of an archived group with its existing memberships and history intact.
_Avoid_: Recreation

**Group home location**:
The canonical city or region that geographically anchors a group. It is distinct from the specific places where the group's huddlz meet.
_Avoid_: Group venue, default venue

**Address book**:
A group's managed collection of reusable physical meeting places.
_Avoid_: Saved locations, group locations, venues

**Address book location**:
One physical meeting place in a group's address book, optionally given a friendly name. It carries its own local scheduling context, which a huddl takes on when the location is chosen for it.
_Avoid_: Saved location, group location, venue, group home location

**Huddl**:
A single gathering organized by a group. A huddl may be in-person, virtual, or hybrid.
_Avoid_: Event, huddle, meeting

**Huddl location**:
The physical meeting place of an in-person or hybrid huddl, always chosen from the group's address book. A virtual huddl has no huddl location.
_Avoid_: Group home location, typed address

## Scheduling and discovery

**Group time zone**:
The local scheduling context derived from a group's home location.

**Huddl time zone**:
The local scheduling context of a huddl. It comes from the huddl location for an in-person or hybrid huddl and from the group's time zone for a virtual huddl; huddl cards display time in this zone.

**Huddl schedule**:
The huddl's date and wall-clock time in its time zone. A recurring huddl retains its local wall-clock time across daylight-saving changes.

**Search location**:
The place that anchors a geographic huddl search, including its distance radius and local date boundaries. Without a search location, the viewer's browser time zone supplies those boundaries.

**Home search location**:
A member's saved place that serves as their default search location. It is a resolved place with its own local scheduling context, not a personal time-zone preference.
_Avoid_: User time zone, home time zone

**Calendar time zone**:
The viewer's browser-reported time zone, used to arrange and display the personal calendar. The calendar identifies this time zone to the viewer.

## Organizing

**Turnout**:
An organizer's rough count of the people who actually came to a huddl: people in the room for an in-person huddl, people on the call for a virtual one, both for a hybrid one. Optional, recorded after the huddl ends, and visible only to the group's organizers and owner.
_Avoid_: Headcount, attendance, check-in

**Show rate**:
Turnout as a share of a huddl's RSVPs, not counting the waitlist. It can exceed 100% when more people come than RSVPd.
_Avoid_: Attendance rate, conversion

**Overview**:
The organizer-only summary page for a group: how membership, RSVPs and turnout are moving over a chosen period.
_Avoid_: Dashboard, analytics, stats page

**Activity**:
The group's own record of what people did: joined or left, RSVPd or cancelled, joined a waitlist or got a spot from it, accepted an invitation. Appended as those actions run, so it remembers what the membership and RSVP rows forget, and shown newest first on the overview to the group's organizers and owner.
_Avoid_: Audit log, events, history, feed (in the domain; "feed" is fine for the panel)
