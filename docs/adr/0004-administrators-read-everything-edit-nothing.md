# Administrators read everything and edit nothing they do not organize

Administrators used to bypass every policy in the Communities domain, so anyone with the admin role could edit any group, huddl, member list or image. Being an administrator is a platform role, not a group role, and the blanket bypass made it impossible to say what an administrator had done as themselves. We decided that administrators keep every read (the platform overview and troubleshooting depend on seeing everything) and lose every write outside the admin area: creating, editing and deleting a group's content depends on owning or organizing that group, administrator or not. An administrator who needs to act inside a group either holds a role there or views huddlz as the person concerned.

Viewing as someone (impersonation in the code) is the troubleshooting tool that replaces the bypass. It is administrator-only, never targets another administrator, applies the target's permissions and none of the administrator's, is announced on every page, and is recorded from start to stop. Group activity written meanwhile points at the record, so the log can say both who acted and who was at the keyboard.

## Considered options

- **Keep the bypass, add an audit trail.** Rejected: the actions would still be the administrator's, taken with rights no group gave them, and every organizer-only rule would need an admin exception in the UI.
- **A separate "support" role with narrower editing rights.** Rejected for now: it recreates the same question one level down. Viewing as the person needs no new permission model.

## Consequences

Edits to groups and huddlz have no change history, so a change made while viewing as someone is attributable to the viewing only by its time window; #565 is where a change history lands. The organizer workspace and the archived-group lock treat administrators like anyone else. Anyone signed in can still create a group.
