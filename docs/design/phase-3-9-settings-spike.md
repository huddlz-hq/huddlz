# Phase 3.9 — Settings tab spike (design note)

**Status:** spike complete; tab deferred. Tracked in `iteration-backlog.md` §3.9.

## Question

Can the prototype's Settings tab — "organizer defaults" for visibility, RSVP windows, reminder schedule, default capacity, attendee questions — ship as a thin wrapper over existing fields, or does it need new model work?

## Answer

**Defer the tab.** Almost every field the prototype names is missing from the schema, and the one that exists (`User.notification_preferences`) already has a dedicated page at `/profile/notifications` reachable from the avatar dropdown. A stub tab would duplicate that page and nothing else, so it's removed from the sidebar until the underlying defaults model lands. Same pattern as 3.7 (Drafts).

## Field-by-field audit

| Prototype field | Schema today | Verdict |
|---|---|---|
| **Default visibility** | `Group.is_public` (per-group), `Huddl.is_private` (per-huddl). No org-wide default. | ❌ Need a defaults home before this is meaningful. |
| **RSVP windows** | None. `Huddl` has `starts_at` / `ends_at` / `max_attendees`; no `rsvp_open_at` / `rsvp_close_at` / cutoff. | ❌ Net-new fields on `Huddl` (or a defaults resource), enforcement in `:rsvp` / `:join_waitlist` changes, UI in create/edit forms. |
| **Reminder schedule** | Hardcoded 24h + 1h via `Huddl.reminder_24h_sent_at` / `Huddl.reminder_1h_sent_at`. User-level on/off via `User.notification_preferences` only (`huddl_reminder_24h`, `huddl_reminder_1h`). | ❌ Net-new schedule shape (e.g. `[hours: [24, 1]]`), worker rewrite to consume the schedule, backfill for existing rows. |
| **Default capacity** | `Huddl.max_attendees` exists per-huddl. No default at group / org / user level. | ❌ Needs a defaults home + form wiring. |
| **Attendee questions** | None. No resource. | ❌ Net-new resource (`HuddlQuestion` or similar) plus an answers join (likely on `HuddlAttendee`), validation in RSVP, render in the attendee detail. Largest gap. |

The only field already wired end-to-end is per-trigger email opt-in/out via `User.notification_preferences`, edited at `/profile/notifications`.

## Why this isn't "just build a form"

Every row in the table above implies at least one of:

1. **A new defaults home.** Org-wide defaults need a resource — most natural is an `OrganizerSettings` keyed on user, or a per-`Group` settings extension. Either choice has implications for who edits them (owner only? co-organizers? both?), how policy works, and whether Group-edit and Workspace-Settings agree on which surface owns the field.
2. **Form-side wiring.** The huddl create/edit flows in `HuddlLive.New` / `HuddlLive.Edit` already exist. Whichever new field lands has to be both (a) writable on the huddl directly, and (b) seeded from the defaults when a new huddl is started. Without (b), the defaults are vestigial.
3. **Enforcement.** RSVP windows aren't a display field; they constrain `:rsvp` and `:join_waitlist`. Reminder schedule isn't a display field; the worker (`Huddlz.Notifications.DeliverWorker` and friends) has to honor it. Each of these is a behavior change, not a UI change.

## Decision

Remove the Settings sidebar entry, route, and placeholder for now (matching the 3.7 Drafts decision). Surface the existing notification preferences in the avatar dropdown as before; everything else waits on a real defaults model.

## Follow-up tickets to file

- **3.9-A — defaults model spike.** Decide between `OrganizerSettings` (user-keyed) vs. per-`Group` extension. Output: `phase-3-9-defaults-spike.md`. Includes: which fields belong on the user vs. the group, how policy works, how huddl create/edit seeds from defaults, migration strategy.
- **3.9-B — RSVP windows.** New fields on `Huddl` + enforcement in `:rsvp` / `:join_waitlist` + form wiring. Defaults plugin once 3.9-A picks a home.
- **3.9-C — configurable reminder schedule.** Replace hardcoded 24h+1h with a schedule list; worker rewrite; backfill.
- **3.9-D — attendee questions.** New `HuddlQuestion` + answers shape; RSVP-time capture; surface in the Attendees detail.
- **3.9-E — re-introduce Settings tab.** Once enough of B–D have landed to populate a useful form.

## Cut lines that hold

- "Just link to /profile/notifications from a Settings tab" — that's exactly what the avatar dropdown does. Adding a workspace tab that does the same thing makes the workspace noisier, not more useful.
- "Stub it with the fields that exist (visibility default + per-huddl form pre-fill)" — there is no defaults home today, so there's nothing to write to. Building one is 3.9-A.
