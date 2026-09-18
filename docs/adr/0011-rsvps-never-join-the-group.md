# RSVPs never join the group; drop-ins are reminded once

RSVPing to a huddl never creates a group membership. A signed-in person who RSVPs to a public huddl without joining its public group is a drop-in there. huddlz reminds a drop-in once per group that they can join: a line in the huddl page's RSVP state after they RSVP, a line in the RSVP confirmation email, one email about a day after the first huddl they held an RSVP at completes, and an entry in a "groups you've dropped in on" section of their groups page. Dismissing the reminder for a group ends every reminder for that group. Someone who left a group or was removed from it is never reminded about it. The reminder is a suggestion: joining stays an ordinary one-click action, never a gate on RSVPing.

Membership is a standing promise (the group's new huddlz reach you, the group sits on your groups page) that an RSVP to one huddl does not imply. Making it automatic would turn every drop-in into a member who never asked for the group's mail, and organizers would see a roster that overstates who belongs. Reminding more than once per group treats a considered "not now" as a lapse.

## Considered options

- **RSVP joins the group automatically**, the common pattern elsewhere. Rejected: it forges consent to the group's future notifications and inflates rosters; the person can only undo it by leaving, which reads as rejection.
- **Ask at RSVP time** with a "join the group too" checkbox on the RSVP button. Rejected: it adds a decision to the one action we want frictionless, before the person has met the group.
- **Remind on every RSVP or on a schedule** until they join. Rejected: repeated asks after a decline are nagging; the second ask carries no new information.
- **Site-wide banner** while a drop-in state exists. Rejected: it follows the person onto pages that have nothing to do with the group.

## Consequences

The huddl page's "Hosted by" card becomes membership-aware for signed-in viewers of public groups, and the RSVP-holder state is what unlocks the reminder line. The after-huddl email is an activity notification with the usual preference toggle, unsubscribe link and confirmed-address requirement; it needs one per-person, per-group record that says the reminder was emailed, dismissed, or closed because the person left or was removed. That record carries no reason and no actor, and it is kept for as long as the account and the group exist: it is a standing "don't remind", not audit history, so the two-year window (ADR-0007) does not apply and a removal never turns back into a reminder. Copy says "RSVPd", never "went" or "came", because huddlz knows who RSVPd and not who attended (ADR-0003, ADR-0008). The suggestion also appears once in the notifications inbox, like every other trigger. The groups page gains a section driven by RSVP rows rather than memberships, readable from the API as a groups relationship alongside hosting and joined. Nothing changes for private groups and private huddlz, where membership is already required to RSVP.
