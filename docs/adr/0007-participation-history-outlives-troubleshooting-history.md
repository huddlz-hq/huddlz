---
status: accepted
---

# Participation history outlives troubleshooting history

The shared change history (#568) keeps every version for 90 days, which is what troubleshooting needs. Participation charts need more: a year of who joined, RSVPed, was promoted or removed, and of what each huddl became, compared with the year before. Those facts cannot be reconstructed from current rows once someone leaves or cancels, and the organizer activity feed names only the affected person and is deleted with the group or the account.

We decided that participation history keeps two years and everything else keeps 90 days. Participation history is every membership and attendee version, and a huddl's creation, publication, cancellation, completion, turnout and deletion. A huddl's edits are not participation history: they carry free text and keep the shorter limit. Account deletion still clears the actor link and leaves the fact.

## Considered options

- **A separate participation log.** Rejected: a second history of the same actions, with the actor and automatic flags the first already has.
- **Keep everything for two years.** Rejected: group and huddl descriptions, invitations and account changes would hold free text and contact details far longer than troubleshooting needs.
- **Keep everything for 90 days and decide later.** Rejected: the first year of charts would be missing, the mistake #564 was opened to avoid.

## Consequences

Retention is per version resource, and per action within the huddl stream; the daily prune reads each resource's rule from its `:expire` action. Two years is one twelve-month period plus its comparison; a longer chart is a new decision. No version is read on a hot path, so the longer window costs storage, not request time.
