# Administrators use ordinary group permissions and explicit impersonation

Administrator status grants platform and account administration, with ordinary visibility and group-role permissions everywhere else. It grants neither private-group access nor additional group editing rights. This keeps troubleshooting from becoming an implicit moderation power; private-group auditing for conduct or terms compliance is deferred.

Troubleshooting uses explicit browser-session impersonation with only the target person's identity and permissions. The session identifies that person and offers a stop control that restores the initiating administrator; signing out ends both identities. Self-targeting, administrator targets, and nested impersonation are unsupported in this release. API keys and bearer tokens remain outside this flow.

Start and stop are recorded. Meaningful changes use the shared AshPaperTrail history from #568, which identifies the target, initiating administrator, and impersonation directly. A time window or the organizer activity feed alone cannot attribute edits reliably.

## Considered options

- Keep the blanket bypass and audit its use: rejected because administrators would still act with rights no group gave them.
- Add a support role with narrower editing powers: deferred because it introduces a second group permission model. Impersonation reproduces the permissions of the person being helped.

## Consequences

Administrators retain personal actions and exactly the rights of their own group roles. Platform views respect private visibility; private-group analytics require an owner or organizer role. A future moderation feature needs an explicit access decision rather than restoring the old bypass.
