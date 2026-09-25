# Administrators use ordinary group permissions and explicit impersonation

Administrator status grants platform and account administration, with ordinary visibility and group-role permissions everywhere else. It grants neither private-group access nor additional group editing rights. This keeps troubleshooting from becoming an implicit moderation power; private-group auditing for conduct or terms compliance is deferred.

Troubleshooting uses explicit browser-session impersonation with only the target person's identity and permissions. The session identifies that person and offers a stop control that restores the initiating administrator; signing out ends both identities. Self-targeting, administrator targets, and nested impersonation are unsupported in this release. API keys and bearer tokens remain outside this flow.

Start and stop are recorded. Meaningful changes use the shared AshPaperTrail history from #568, which identifies the target, initiating administrator, and impersonation directly. A time window or the organizer activity feed alone cannot attribute edits reliably.

## Considered options

- Keep the blanket bypass and audit its use: rejected because administrators would still act with rights no group gave them.
- Add a support role with narrower editing powers: deferred because it introduces a second group permission model. Impersonation reproduces the permissions of the person being helped.

## Consequences

Administrators retain personal actions and exactly the rights of their own group roles. Platform views respect private visibility; private-group analytics require an owner or organizer role. A future moderation feature needs an explicit access decision rather than restoring the old bypass.

## Exception: platform-wide aggregate copy counts

The admin overview's Copies panel may count copying activity across every group,
including private groups, private huddlz, drafts and deleted copies whose audit
history is still retained. It returns only total copies, distinct organizer and
group counts, source-timing counts, and period comparisons. It exposes no names,
identifiers, individual records, content, or drill-down into private activity.

Filtering these adoption figures by the administrator's memberships makes the
platform totals incomplete and different for each administrator. Complete
aggregate counts are therefore an explicit exception to the visibility rule
above. Small counts remain visible; the counts themselves are authorized staff
information. This exception does not grant private-content access, change the
visibility of other overview panels, or expose staff analytics through public
APIs. The administrator-only dashboard action remains the access boundary.
