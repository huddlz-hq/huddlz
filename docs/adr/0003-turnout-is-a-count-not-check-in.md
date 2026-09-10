# Turnout is a headcount, not per-person check-in

Organizers want to know how many people actually came to a huddl, because RSVPs mislead in both directions: some groups draw more walk-ins than RSVPs, others see half the RSVPs not show. We decided to record turnout as one or two integers per huddl (people in the room for in-person, people on the call for virtual, both for hybrid), entered by an organizer after the huddl ends, always optional and always skippable. Turnout and show rate are visible to the group's organizers and owner only.

## Considered options

- **Per-person attendance marking or QR self check-in.** Rejected for now: marking names does not scale past a few dozen people, virtual versus in-person check-in gets complicated, and any per-person burden means the data stops being recorded. A per-person layer can be added later as an optional extra on top of the count, but the count is the contract.
- **RSVPs as the turnout proxy.** Rejected: it is exactly the number that is wrong for these groups.

## Consequences

Show rate is turnout divided by RSVPs and can exceed 100%. There is no per-member attendance history, so nothing should be built that needs to know whether a specific person came.
