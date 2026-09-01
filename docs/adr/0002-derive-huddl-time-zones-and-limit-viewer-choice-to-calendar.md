---
status: accepted
---

# Derive huddl time zones and limit viewer choice to Calendar

Every group has a required physical **Group location**, even if it only organizes virtual huddlz. Creating a group therefore requires selecting a resolvable city or area rather than entering an optional free-form location. The Group time zone is derived from that selected location; it is not an independent organizer preference.

Physical and hybrid huddlz derive their authoritative **Huddl time zone** from their own physical location. Virtual huddlz copy the Group time zone when created, so organizers do not need to select a time zone for them. Changing the Group location re-derives the Group time zone but does not alter existing huddlz, preserving the wall-clock scheduling intent under which they were created.

People do not choose an account or Profile time zone, and organizers do not choose a Huddl time zone independently of its location. **Calendar time zone** is the only viewer-controlled time-zone concept: it defaults to the browser time zone and may be changed within Calendar so huddlz from different time zones can share coherent Day, Week, and Month boundaries. Discover filters by physical proximity rather than time zone, and non-Calendar surfaces present each huddl in its own authoritative local time.

The authoritative Huddl time zone remains stored even when it is derived and not exposed as a control. UTC instants support ordering and comparison, while the named IANA zone preserves wall-clock intent across daylight-saving changes, notifications, calendar exports, recurrence, and later schedule edits.
