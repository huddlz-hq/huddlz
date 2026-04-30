# Email notifications

Spec for huddlz email notifications. The full inventory of triggers, who gets each one, and the order to build them in.

Status: spec only. Implemented today: account confirmation (A1) and password reset (A2) via AshAuthentication. Everything else is unbuilt.

Out of scope: mobile push, in-app notifications, SMS.

## Categories

Every email lands in one of three buckets:

| Category | Always send? | Examples |
|---|---|---|
| Transactional | Yes. No opt-out. | Account confirmation, password reset, security alerts, huddl cancelled, you were removed from a group |
| Activity | Default ON, per-category opt-out | Huddl reminders, new member joined, RSVP changes, role changes, new huddl in your group |
| Digest | Default OFF, opt-in | Weekly upcoming-huddlz digest, "what you missed" recaps |

Activity and Digest emails need an unsubscribe link in the footer (per-category and full opt-out).

## Triggers

Each trigger has an ID (e.g. C3) used throughout the doc and the GitHub issues.

### A. Authentication & account

| ID | Trigger | Recipient | Category | Status |
|---|---|---|---|---|
| A1 | User registers | New user | Transactional | EXISTS (`SendNewUserConfirmationEmail`) |
| A2 | Password reset requested | User | Transactional | EXISTS (`SendPasswordResetEmail`) |
| A3 | Password successfully changed | User | Transactional | "If this wasn't you…" security notice |
| A4 | Email address changed | Old + new email | Transactional | Security notice on both addresses |
| A5 | Account role changed by admin | User | Activity | Triggered from `lib/huddlz_web/live/admin_live.ex:45` |

### B. Group membership

| ID | Trigger | Recipient | Category | Notes |
|---|---|---|---|---|
| B1 | User joins a public group | Group owner + organizers | Activity | One email per join. Cap at N/day if a group goes viral. |
| B2 | User added to a private group | The added user | Activity | "You're now a member of X" |
| B3 | User removed from a group | The removed user | Transactional | They lose access |
| B4 | User's role changed (member ↔ organizer, etc.) | The user | Activity | |
| B5 | User leaves a group on their own | — | None | They did it themselves |
| B6 | Group deleted/archived | All members | Transactional | They lose access to data they care about |
| B7 | Group ownership transferred | Old + new owner | Transactional | |

### C. Huddl lifecycle

| ID | Trigger | Recipient | Category | Notes |
|---|---|---|---|---|
| C1 | New huddl created in a group | All group members | Activity | Default ON. Body links to settings page. |
| C2 | Huddl details meaningfully changed | All current RSVPs | Activity | "Meaningful" = `starts_at`, `ends_at`, `location`, `virtual_link`, `title`. Skip cosmetic edits. |
| C3 | Huddl cancelled / deleted | All current RSVPs | Transactional | Highest priority. People may have travel plans. |
| C4 | Recurring series modified | RSVPs of the next upcoming instance only | Activity | Subsequent instances are covered by their own reminders (D1/D2). |

### D. Huddl reminders (time-based, Oban cron)

| ID | Trigger | Recipient | Category | Notes |
|---|---|---|---|---|
| D1 | Huddl starts in 24 hours | All RSVPs | Activity | Most important reminder. Includes `.ics`. |
| D2 | Huddl starts in 1 hour | All RSVPs | Activity | Make virtual link prominent. Includes `.ics`. |
| D3 | Huddl ended (post-event) | RSVPs who attended | Digest | Recap, photos, "rate this huddl". Not in v1. |

Reminder jobs must be (a) scheduled when a huddl is created or rescheduled, (b) cancelled when a huddl is cancelled. Resolve recipients (RSVPs) at job run time, not at schedule time, so RSVPs added after creation still get the reminder.

### E. RSVPs

| ID | Trigger | Recipient | Category | Notes |
|---|---|---|---|---|
| E1 | Someone RSVPs to your huddl | Group owner + organizers | Activity | Per-RSVP, no cap in v1. Organizers tune via settings. |
| E2 | Someone cancels their RSVP | Group owner + organizers | Activity | Same volume rule as E1. |
| E3 | RSVP confirmation to the user | User | Activity | "You're going to X." Includes `.ics`. |
| E4 | RSVP cancellation confirmation | User | None | Skip — overkill |

### F. Digests (deferred, v2)

| ID | Trigger | Recipient | Category | Notes |
|---|---|---|---|---|
| F1 | Weekly upcoming-huddlz digest | All members, opt-in | Digest | Re-engagement |
| F2 | "30 days since your last visit" | Inactive users, opt-in | Digest | Reactivation. Easy to feel spammy. |

## Not notifications

These do **not** trigger emails:

- Group description / image / location updates
- Huddl description edits (only the C2 fields trigger)
- Profile updates (display name, avatar, home location)
- Comments / messages (no comment system exists yet)
- Public huddl/group page views
- Admin viewing user list

## Recipient rules

Apply to every trigger:

1. **Actor exclusion** — never email the person who triggered the action. If you RSVP, the organizer gets the email, not you.
2. **Owner + organizers** — for group-leadership emails (B1, E1, E2), notify both, deduped.
3. **Dynamic RSVP set** — for huddl emails (C2, C3, D1, D2), recipients are the RSVPs *at send time*, not at huddl creation time.
4. **Skip unconfirmed users** — don't email until `confirmed_at` is set (except A1).
5. **Skip soft-deleted users**.

## Decisions

Locked for v1, no re-litigation:

1. C1 audience = every group member. Mitigated by the settings page.
2. E1/E2 volume = per-RSVP, no cap. Daily digest is a v2 idea.
3. C4 = one email about the next upcoming instance. Later instances rely on D1/D2.
4. `.ics` attachments ship in v1 on E3, D1, D2.
5. Defaults: Activity ON, Digest OFF, Transactional always on.

## Settings page

Lives under profile (`lib/huddlz_web/live/profile_live.ex`) or a new `/profile/notifications` route. One toggle per item below, stored in `User.notification_preferences` (JSONB map keyed by trigger code, e.g. `"huddl_new"`, `"huddl_reminder_24h"`, `"rsvp_received"`).

Toggles (and the trigger they map to):

- Account security alerts (A3, A4 — always on, shown disabled for transparency)
- New huddl scheduled in a group I'm in (C1)
- Huddl I'm RSVPd to was updated (C2)
- Huddl I'm RSVPd to was cancelled (C3 — always on, shown disabled)
- 24-hour reminder (D1)
- 1-hour reminder (D2)
- Someone RSVPd to a huddl I organize (E1)
- Someone cancelled an RSVP to a huddl I organize (E2)
- RSVP confirmations to me (E3)
- Group membership changes affecting me (B2, B3, B4, B6, B7)
- Someone joined a group I organize (B1)

Unsubscribe links in email footers deep-link to a confirmation page, then a POST flips a single key via signed token and redirects.

## Implementation

- **`User.notification_preferences`** — JSONB map keyed by trigger code. Defaults applied at read time, so adding a new key doesn't need a backfill.
- **Sender modules** — one per email under `lib/huddlz/notifications/senders/` (or colocated under `lib/huddlz/accounts/user/senders/` to match AshAuthentication). Each sender: build email, check preferences, deliver.
- **Ash notifiers** — most action-driven emails (B1, B3, C1, C3, E1, E2, E3) attach as `Ash.Notifier` modules on the resource. Avoids scattering side-effects across LiveViews.
- **Reminder scheduling (D1, D2)** — when a huddl is created, schedule two Oban jobs (`scheduled_at: starts_at - 24h` and `starts_at - 1h`). On huddl update, cancel + reschedule. On RSVP create/destroy, do *not* touch the huddl-level job — the job resolves recipients at run time.
- **Unsubscribe** — `Phoenix.Token` signed payload `{user_id, category}`, route at `/unsubscribe/:token`. GET shows confirmation; POST flips the preference and redirects to the settings page.
- **`.ics` generation** — one shared helper module, used by E3, D1, D2.

### Existing infrastructure to build on

- Mailer: `Huddlz.Mailer` (`lib/huddlz/mailer.ex`), Swoosh, `support@huddlz.com` from-address. Local adapter in dev (`/dev/mailbox`), Mailgun in prod, Test adapter in tests.
- Sender pattern: `lib/huddlz/accounts/user/senders/send_password_reset_email.ex` and `send_new_user_confirmation_email.ex`.
- Background jobs: Oban + AshOban configured in `config/config.exs:22-32`, cron plugin enabled. Image-cleanup AshOban triggers show the pattern.

### Critical files

- `lib/huddlz/communities/huddl.ex:69-270` — Huddl actions (create, update, destroy, rsvp, cancel_rsvp)
- `lib/huddlz/communities/huddl_attendee.ex:49-92` — RSVP create/destroy
- `lib/huddlz/communities/group.ex:64-128` — Group actions
- `lib/huddlz/communities/group_member.ex:65-130` — Membership join/leave/add/remove
- `lib/huddlz/accounts/user.ex` — needs `notification_preferences`
- `config/config.exs:22-32` — add notification queue
- `lib/huddlz_web/router.ex` — needs `/unsubscribe/:token`

## Sender conventions

Rules every `Huddlz.Notifications.Senders.*` module follows. New senders should be cargo-cultable from any existing one.

### HTML escaping

Every user-controlled string interpolated into `html_body` MUST go through `Huddlz.Notifications.Senders.HtmlEscape.escape/1`. This includes display names, email addresses, and any value that originated outside the sender module. Plain-text bodies use the raw value.

### Footer

- **Transactional** senders: no footer. There is no preference toggle, so an unsubscribe link would be misleading.
- **Activity** senders: include `<hr/>` + a settings link + an unsubscribe link. Generate the unsubscribe token via `Huddlz.Notifications.unsubscribe_token(user, trigger)` so the route flips the right preference key.

(When the second activity sender lands, lift the inline footer HTML into a shared helper — until then, inline keeps the diff small.)

### Recovery advice in security notices

Include a `/reset` link **only when the recipient's address is the current account email**, i.e. when the password-reset channel itself is unchanged.

| Sender | Recipient | Recovery channel intact? | Link `/reset`? |
|---|---|---|---|
| `password_changed` | current email | yes | yes |
| `email_changed` (audience: "old") | previous email | **no** — reset email goes to the new (possibly attacker-controlled) address | no — direct to support |
| `email_changed` (audience: "new") | new email | n/a — confirmation only | no |

When the channel has moved, lead with "contact support" and explicitly note that `/reset` won't help. Anything else gives the user a false sense of recovery.

### Test floor

Each sender test should at minimum assert:

- greeting includes the user's display name
- recipient is correct (`email.to`)
- `email.from` matches the configured `Mailer.from()`
- subject line
- a body keyword that anchors the message
- `<script>` payload in display name is HTML-escaped
- `refute email.text_body =~ "<"` — no markup leaks into plain text

## Testing

- One sender test per trigger in `test/huddlz/notifications/`, using `Swoosh.Adapters.Test`.
- One feature test per trigger in `test/features/`, performing the action and asserting the email.
- D1/D2 worker: `Oban.Testing` unit test with a mocked clock.
- Manual: dev run, perform every flow, check `/dev/mailbox`.
- `mix precommit` clean throughout.

## Build order

Each step is shippable on its own.

1. Foundation — `notification_preferences`, unsubscribe route, settings page, `.ics` helper, sender-module pattern
2. C3 — exercises the notifier pattern end-to-end on a transactional email
3. D1 + D2 — exercises Oban scheduling/cancellation and `.ics`
4. C1 + C2
5. E1 + E2 + E3
6. C4 (small once C2 is in place)
7. B1–B7
8. A3–A5
9. F1/F2 — separate epic, post-v1 (see #119 for current feedback)
