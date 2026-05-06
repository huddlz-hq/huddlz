# Phase 2.4 — Invites spike (design note)

**Status:** spike complete; implementation tracked as Phase 2.4.1 in `iteration-backlog.md`.

## Question

Does the Invites tab on `/me` need a new `HuddlInvite` Ash resource, or can it be derived from existing state?

## Answer

**Defer the new resource.** Ship the Invites tab as a tighter-filtered view of the `Notification` resource that landed in 2.3. Capture two real product gaps as separate follow-ups.

## What the prototype shows

Three card types in the prototype's Invites view:

1. **Invited** (Accept / Decline) — organizer reached out to a specific user about a specific huddl
2. **Waitlist opened** (Claim spot / Pass) — capacity freed up on a huddl the user is waitlisted for
3. **Join approved** (Open group / Mute) — the user's pending group join request was approved

## Existing state

- **`HuddlAttendee`** has `waitlisted_at`. `PromoteFromWaitlist` (in `cancel_rsvp.ex` and `promote_on_capacity_increase.ex`) **auto-promotes** waitlisted users when capacity opens — they go straight from waitlisted to attending and receive a `:waitlist_promoted` notification.
- **`GroupMember`** roles are `owner | organizer | member`. There is **no request-to-join → approve flow today**. `:join_group` is direct (for public groups, gated by `PublicGroup` check). `:add_member` is owner/organizer-initiated and fires `:group_member_added`.
- **`Notification`** (Phase 2.3) persists every triggered event with `trigger`, `payload`, `title`, `description`, `source_url`, and `read_at`. The Updates tab already renders it.

## Card-by-card recommendation

| Prototype card | Plan | Rationale |
|---|---|---|
| **Invited** (direct invite) | **Defer** — no shipping in 2.4.1. Captured as gap below. | No `HuddlInvite` resource. Adding one is real product work and we don't have product commitment yet. |
| **Waitlist opened** | Surface recent `:waitlist_promoted` notifications. | The user is already promoted; the card informs and offers a "Cancel if you can't make it" path. No new state machine. |
| **Join approved** | Surface `:group_member_added` as "Added to *group*". | Today's flow is direct-add, not request-approve. We can render the resulting notification but the card semantically becomes "you're in" rather than "your request was approved". |

## Phase 2.4.1 implementation shape

Tab is a thin filter on the existing `Notification` resource:

- Add a code interface like `Notifications.list_invites/1` (or named filter on `:for_user`) that selects triggers in a "needs response" set — initially `[:waitlist_promoted, :group_member_added]`.
- Reuse the `<.notification_card>` already rendered on the Updates tab (or share via a small extracted component).
- Tab intro: "Things that need a response from you."
- Empty state: "No invites right now. When organizers invite you to a huddl or group, they'll show up here."

No new resource, no migration, no schema changes. The MeLive `:invites` placeholder branch becomes a real `load_tab` clause.

Estimated diff is comparable to Phase 2.2 (My Groups) — small.

## Documented gaps (capture as GitHub issues)

These are not addressed by 2.4.1 and warrant their own future tickets:

### Gap 1 — Private groups have no invitation mechanism

Private groups exist (`Group.is_public == false`), but the only way for someone to join is `:add_member` invoked by an existing owner/organizer who already knows the user's identity. There is no email invite, no invite code, and no way for an organizer to invite a user who doesn't yet have a huddlz account. This is a real product hole for private groups.

**Possible direction:** A `GroupInvite` resource with `group_id`, `invitee_email`, `invited_by_id`, `state`, `token`, `expires_at`. Email link → claim flow → membership. Private-group MVP fix.

### Gap 2 — Direct huddl invitations have no model

There is no way for an organizer (or a member) to say "I want Sarah specifically to come to this." This is a natural agent-tool ("invite Sarah to my coffee") aligned with the platform's AI-native direction, and it's the prototype's "Invited" card.

**Possible direction:** A `HuddlInvite` resource with `huddl_id`, `invitee_id` (or `invitee_email`), `inviter_id`, `state` (`:pending | :accepted | :declined | :expired`), `message`, `expires_at`. State transitions as actions; accept creates a `HuddlAttendee`.

These two gaps may share a base resource (a generic `Invite` polymorphic on target) — but that's a design decision for the implementing tickets, not this spike.

## Trigger-of-decision (when to revisit)

Revisit and ship Gap 2 (direct invitations) when:
- Private-group product surface needs real onboarding (Gap 1 forces the same shape), OR
- Agent integration is far enough along that "invite person X to huddl Y" is a concrete tool call we want to support, OR
- We see explicit user demand from an early cohort.

Until then, deferring is correct: building an invitation state machine without product pull is scaffolding that may not match real usage.
