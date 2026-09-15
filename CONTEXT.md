# huddlz

huddlz helps groups organize and discover gatherings while preserving the local scheduling context of each group and huddl.

## Platform usage

**Display name**:
The name a person chooses to be recognized by on huddlz. Nicknames, international text, punctuation, emoji, and business names are welcome; web addresses, email addresses, and overt advertisements do not belong in a display name.

**Sign-up**:
The creation of a huddlz account, distinct from confirming its email address. A historical estimate of its date is not an observed sign-up date.

**Email confirmation**:
Proof that a person can access a particular email address associated with their huddlz account. It establishes ownership of that address, not the person's identity or trustworthiness.

**Pending email change**:
A requested replacement for an account's email address that has not completed the required approvals. The existing address remains active until the change completes.

**Active user**:
A signed-in person who used huddlz during the selected period, including browsing without joining a group, RSVPing, or organizing a huddl. The platform overview shows this figure as active people.

**Active day**:
The record that a signed-in person used huddlz on a UTC calendar date. At most one exists per person per date, and it holds nothing else about the visit.

**Visitor**:
A person browsing huddlz without being signed in, whether or not they have an account.

**Confirmed address**:
An email address whose owner has followed a confirmation link sent to it. Confirmation proves ownership of the address, not identity. Huddl reminders and group updates wait until the account's address is confirmed.

**Confirmation link**:
A link sent to an address so its owner can confirm it, minted for that address and usable for three days. Asking for the email again mints another link without spending earlier ones; confirming spends all of the account's links; a link minted for an address the account no longer has confirms nothing.

**Participation history**:
The record of who joined, left, RSVPed, was promoted from a waitlist or removed, and of each huddl's creation, outcome and turnout, kept for two years with the person who acted separate from the person affected. The same two-year window applies to all audit history, including troubleshooting changes.

**Administrator**:
A member of the huddlz staff responsible for platform and account administration. This role is distinct from a group's owner, organizer, or member roles.

**Account suspension**:
An administrator decision that indefinitely removes an account's authenticated access and hides its personal profile and identity from ordinary member surfaces. Restoration requires a finding that suspension was mistaken; suspension is separate from moderation of the groups and huddlz the person owns.

**Suspended account**:
The neutral label every ordinary surface, including the API and notifications, shows in place of a suspended person's name and picture wherever a record must keep its author. The original name is read only in account administration and participation history.

**Account restoration**:
An administrator's manual reversal of a suspension judged mistaken. It lets the person sign in again from scratch; revoked sessions and API keys stay revoked and released spots are not rebooked.
_Avoid_: Unban, reactivation

**Account report**:
A confirmed member's request for administrators to review an account they can already see, including the organizer of a public huddl without joining its group or RSVPing, for spam or another concern. A report does not itself suspend the account; its details and the reporter's identity are available only to huddlz staff for review.

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
One reusable physical meeting place in a group's address book, optionally given a friendly name and unit identifier; different units in the same building can be separate entries. It carries its own local scheduling context, which a huddl takes on when the location is chosen for it.
_Avoid_: Saved location, group location, venue, group home location

**Unit identifier**:
The optional number or alphanumeric designation of a meeting place within a building, such as 711 or 4B. It can identify an apartment, room, suite, or other unit without requiring a type.

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
A member's saved city or region that serves as their default search location. It is a resolved place with its own local scheduling context, not a street address or personal time-zone preference.
_Avoid_: User time zone, home time zone

**Calendar time zone**:
The viewer's browser-reported time zone, used to arrange and display the personal calendar. The calendar identifies this time zone to the viewer.

## Organizing

**Turnout**:
An organizer's rough count of the people who actually came to a huddl: people in the room for an in-person huddl, people on the call for a virtual one, both for a hybrid one. Optional, recorded after the huddl ends, and visible to the group's organizers and owner.
_Avoid_: Headcount, attendance, check-in

**Show rate**:
Turnout as a share of a huddl's RSVPs, not counting the waitlist. It can exceed 100% when more people come than RSVPd.
_Avoid_: Attendance rate, conversion

**Group overview**:
The organizer summary for one group: how membership, RSVPs and turnout are moving over a chosen period.
_Avoid_: Dashboard, analytics, stats page

**Platform overview**:
The administrator summary of growth, huddlz and participation across huddlz as a whole.
_Avoid_: Dashboard, analytics, stats page

**Who's going**:
The people with an RSVP to a huddl, shown on the huddl page and on the API only to people who are going themselves: anyone with an RSVP or a waitlist spot on that huddl. Everyone else sees the count. Group roles and administration grant no exception. After the huddl ends it is still the people who RSVPd, never who came.
_Avoid_: Attendee list, attendees (for the people; "attendee" stays the API resource name), who attended

**Activity**:
The group's own record of what people did: joined or left, RSVPd or cancelled, joined a waitlist or got a spot from it, accepted an invitation. Appended as those actions run, so it remembers what the membership and RSVP rows forget, and shown newest first on the overview to the group's organizers and owner.
_Avoid_: Audit log, events, history, feed (in the domain; "feed" is fine for the panel)
