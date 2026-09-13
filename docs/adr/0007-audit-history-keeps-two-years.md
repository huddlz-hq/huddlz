---
status: accepted
---

# Audit history keeps two years

Keep all shared audit history for two years (730 days), covering a twelve-month period and its comparison period while preserving context for future group history. One retention window applies to every resource and action, including troubleshooting changes and snapshot free text.

## Considered options

- **Two years for participation and 90 days for other changes.** Rejected: it complicates retention and does not give free text a shorter life, because creation and lifecycle snapshots also contain that text. Enforcing a separate content cutoff would require redaction.
- **Keep everything for 90 days and decide later.** Rejected: participation history would disappear before annual comparisons could use it.
- **A separate participation log.** Rejected: the shared history already records the actions, actors and automatic flags needed.

## Consequences

Historical group and huddl content, including edited or deleted text, can remain in audit snapshots for 730 days. Account deletion still clears actor and impersonator links; subject IDs and recorded facts remain until expiry. Existing exclusions for credentials, direct profile/contact values and media paths remain in force. The organizer activity feed keeps its existing deletion behavior.

The daily prune uses one timestamp cutoff for every version resource. Longer retention increases storage, index size and maintenance work. Current pages do not read audit versions; future group history and charts need appropriately indexed, bounded queries and measured performance. Retention does not guarantee constant request time as the database grows.
