# Search & Organize — Iteration Backlog

A living plan for moving the [search-organize prototype](search-and-organize.md) into the LiveView app. The prototype is a starting direction, not a contract — items below will be revised, split, or dropped as we learn from each shipped slice.

## How this is organized

- **Phases** group work that's safe to ship together. Each phase has a clear theme and ships standalone value.
- **Items** are intended to be self-contained: one PR, tests in the same commit, `mix precommit` clean at every boundary.
- **Cut lines** call out what stays out of scope so a ticket doesn't grow.
- A ticket marked _spike_ produces a design note; the implementation ticket comes after.

When we commit to a phase, items can be promoted to GitHub issues with `phase-N` labels.

## Inventory snapshot

What the prototype assumes vs. what already exists:

**In place** — `Group`, `Huddl`, `GroupMember`, `HuddlAttendee` resources; auth at `/sign-in`/`/register`; discovery at `/` (huddlz) and `/groups`; CRUD nested under `/groups/:slug/...`; profile + notification preferences; `Notifications` domain with reminders; partial 16:9 imagery convention.

**Missing or scattered** — global header search; combined huddl+group search; landing page distinct from discovery; consolidated `/me` dashboard; organizer workspace shell; cross-group attendee/member views; drafts and calendar surfaces; messages/announcements feature; huddl invites model; richer account menu; two-column auth layout; multi-column footer.

---

## Phase 0 — Shell

Foundation for everything else. Low risk, all later work assumes the new chrome.

### 0.1 Global header with search input
Replace the header in `HuddlzWeb.Layouts.app/1` with: `huddlz` brand + search input + `Organize` link + auth controls (or avatar). Search submits to the existing huddlz index for now.
- **Cut line:** new combined-results route (Phase 1.2).

### 0.2 Account menu redesign
Avatar dropdown exposes: My Huddlz, My Groups, Organizer workspace, Preferences, Public home, Sign out. New entries link to existing routes (or 404 placeholders) until later phases land.
- **Cut line:** new `/me` and `/organize` routes themselves.

### 0.3 Footer with grouped columns
Replace single-line footer with Product / Help / Legal / Open columns. Static links only.

---

## Phase 1 — Discovery

Highest visible UX shift; pulls the brand together around search.

### 1.1 Landing page — ✅ shipped
**Decision:** `/` is `LandingLive` for anonymous visitors (hero + value tiles + upcoming preview + organizer band). Authenticated users are redirected from `/` to `/me` via the `:redirect_to_me_if_authenticated` LiveUserAuth hook. Discovery (search, filters, all-upcoming, scoped views) moved to `/discover` and is shared by anonymous and signed-in users. Personal sections (Hosting / Attending) live on `/me` (a thin shell — Phase 2.1 will fill in tabs).
- Featured-huddl curation card is **deferred**: needs a `Huddl.is_featured` attribute + admin selection UI; revisit alongside Phase 3.x organizer workspace.
- **Cut line:** new search results route (1.2).

### 1.2 Combined search results route — ✅ shipped
**Decision:** No new `/search` route. Folded combined results into the existing `/discover` (`HuddlzWeb.HuddlLive`). The page is filter-driven via two URL params:
- `?scope=huddlz|groups` (default `huddlz`) — selects which resource type renders. Two scope chips ("Huddlz" / "Groups") sit above the search form; the `All` scope from the prototype was dropped because blending huddlz + groups in one feed had no shared relevance ranking and produced padded layout. Huddlz are the primary entity; groups are reachable via the chip.
- `?yours=hosting|attending` (existing) — huddlz-only, ignored under `scope=groups`.
Group results reuse `Communities.search_groups` plus an inline offset-pagination helper modeled on `GroupLive.Index.paginate_with_count`. Results-head copy, scope chips, mono section labels, and per-scope empty states transcribed from the search-organize prototype. Type badges deferred (each scope is homogeneous so the section label is sufficient).
- Filter panel slide-in (Phase 1.3): location/date/format/topics/huddl-options/sort.
- Group distance/location filtering: tracked alongside 1.3.
- **Cut line:** filter panel polish (1.3).

### 1.3 Filter panel slide-in — ✅ shipped
**Decision:** Lifted the right-side drawer markup from the prototype (bottom sheet on mobile via Tailwind responsive classes). Built inline in `HuddlLive`, not extracted to a shared `<.drawer>`. Sections shipped: Date, Format, Location, Sort. Each toggle is a `<.link patch>` that computes a new URL via `form_params_from_assigns` + override merge — clicking an active toggle deselects (URL drops the param). A new `:sort` argument was added to the `Huddl :search` action with `:soonest` (default) and `:newest`. Active-filter chips below the chrome row now include a Sort chip when `?sort=newest`. Reset button reuses the existing `clear_filters` event.
- **Topics dropped:** No data model exists for topics on Group/Huddl, and "Groups I follow" needs a follow association we don't have. Deferred to a separate ticket.
- **"Huddl options" dropped** (Has open spots / Free only / Include online): no underlying data; defer alongside topics.
- **Apply button dropped:** uses live URL patches instead, matching today's filter behavior.
- **Cut lines that held:** saved searches; relevance/nearest sort; format multi-select.

### 1.4 16:9 imagery audit — ✅ shipped
**Decision:** Audit found `aspect-video object-cover` already applied to every cover surface (cards in `community_components.ex`, detail heroes in `huddl_live/show.ex` and `group_live/show.ex`, all four upload-form previews) and `Huddlz.ImageProcessing.create_banner_thumbnail/3` already coerces uploads to a 1280×720 JPEG via `Image.thumbnail(..., crop: :center)`. Both layers were already in place. Shipped a small PR to (a) align helper-text on `huddl new`/`huddl edit` forms with the canonical "(16:9 ratio recommended)" wording the group forms use, and (b) add DOM regression assertions (`[class*='aspect-video']`) on huddl + group card grids and detail heroes so future refactors can't quietly drop the ratio. Profile avatar deliberately left square. No client-side cropper added; server-side center-crop is the single source of truth.

---

## Phase 2 — Member dashboard `/me`

Personal surface, distinct from organizer tools.

### 2.1 `/me` shell + My Huddlz tab
New LiveView with tabs (My Huddlz / My Groups / Invites / Updates). My Huddlz lists upcoming RSVPs, waitlisted, past attendance. Backed by `HuddlAttendee.by_user` (with actor).

### 2.2 My Groups tab
Joined / followed / organized splits. Reuses `Group.get_joined` and `Group.get_by_owner`.
- **Open question:** "Followed" implies a new association. If we don't want a new model yet, drop "followed" from this iteration and ship joined + organized only.

### 2.3 Updates tab
Notifications feed from the existing `Notifications` domain. Read/unread + jump-to-source actions.
- **Cut line:** notification preferences live at `/profile/notifications` already; only show controls inline if cheap.

### 2.4 Invites — spike — ✅ shipped
**Decision:** Defer a new `HuddlInvite` resource. Ship the Invites tab as a tighter-filtered view of the `Notification` resource shipped in 2.3. See [phase-2-4-invites-spike.md](phase-2-4-invites-spike.md) for the full design note.

Two product gaps captured for follow-up tickets (no new model in the MVP tab):
- Private groups have no invitation mechanism (only path in is `:add_member` by an existing organizer who already knows the user).
- Direct huddl invitations ("invite Sarah specifically") have no model — natural fit for the AI-native direction.

### 2.4.1 Invites tab — implementation
Wire `/me?tab=invites` as a filtered view of `Notification`. "Needs response" filter starts at `[:waitlist_promoted, :group_member_added]`. Reuses the notification card from the Updates tab (or shares via a tiny extracted component). Empty state copy and tab intro per the spike note.
- **Cut line:** no new resources, no schema changes, no state machines. Direct invitations + group invitations are separate future tickets per the spike's documented gaps.

---

## Phase 3 — Organizer workspace `/organize`

Largest phase. Each tab is a separate ticket that drills into existing CRUD until that surface gets its own polish.

### 3.1 Workspace shell + Overview
Sidebar layout (`HuddlzWeb.OrganizeLive`) with the eight prototype tabs as routes/links. Overview shows metrics + active work feed. Other tabs render placeholders that link to existing pages.
- **Cut line:** every other tab (its own ticket).

### 3.2 Groups tab
List groups the actor organizes; row click drills into `/groups/:slug/edit`. Reuses `Group.get_by_owner`.

### 3.3 Huddlz tab
Cross-group huddl list with Live / Draft / Past filters. Needs a new `huddlz_for_organizer` read action scoped by actor.

### 3.4 Create-huddl subview
Port `HuddlLive.New` form into the workspace shell: cover upload, basics, date/format, address + geocode (already supported), publish settings.
- **Cut line:** new model fields beyond what `Huddl` already has.

### 3.5 Attendees tab — ✅ shipped
**Decision:** Shipped a master-detail view inside the workspace shell. The index lists upcoming organized huddlz (sorted by start time, ascending) with cyan RSVP and outline waitlist count badges; clicking a row patches `?huddl=<id>` and renders a detail view with two columns — Attending and Waitlist — populated by `HuddlAttendee.by_huddl` / `waitlist_for_huddl` actions. A new policy was added to `:waitlist_for_huddl` (`IsGroupOwnerOrOrganizer`) since the waitlist is an operational view; `:by_huddl` already had the right policy. Detail rows show display name (falling back to email) and a relative timestamp; waitlist rows are numbered to surface position. The `Edit huddl →` link drops into the existing edit page rather than building duplicate edit affordances.
- **Cut lines that held:** message attendees (Phase 4.x); mark-checked-in (needs new field); move to waitlist (no UX yet); past huddlz filter (this surface is operational, "what's coming up next").
- **Cut line:** check-in workflow if it requires new fields.

### 3.6 Members tab — ✅ shipped
**Decision:** Shipped a read-only master-detail view mirroring 3.5. The index lists groups the actor owns (sorted by name, reusing `Group.get_by_owner`) with member counts and visibility badges; clicking a row patches `?group=<slug>` and renders the roster in three role-grouped panels — Owner / Organizers / Members — each ordered by created_at. Each row shows display name (falling back to email), join date, and a role badge. The detail view ends with a small italic note that role changes / removals haven't been wired into the workspace yet.
- Scoped to **owned** groups only, matching 3.2's behavior. Organizers-but-not-owners don't see groups they only co-organize. If we want that, the right fix is a `groups_for_organizer` action paralleling `huddlz_for_organizer`; it stayed out of scope for this slice.
- **3.6.1 follow-up — member ops:** role change (member ↔ organizer), remove member, add-by-search. The actions exist on `GroupMember` (`:change_role`, `:remove_member`, `:add_member`); only the UI is missing. Owner-only by current policy.
- **Cut lines that held:** approvals (no model — flagged in 2.4 spike), invitations to private groups (no model), bulk operations, search/filter within a group's roster.

### 3.7 Drafts tab
Lists huddl + group drafts with a completion checklist. Needs `:draft` state reads on both resources (verify they exist; add if not).

### 3.8 Calendar tab
Month / week / agenda view across organized groups. Largest unknown; spike before committing.
- **Cut line:** calendar sync / iCal export.

### 3.9 Settings tab
Organizer defaults — visibility, RSVP windows, reminder schedule, default capacity, attendee questions. Form-heavy; some fields likely don't exist yet (small spike to enumerate).

---

## Phase 4 — Messages (new domain)

### 4.1 Spike: messages model
Decide resource shape: direct message vs broadcast vs scheduled reminder; audience selector segments (group / huddl / attendees / waitlist / no-shows). Output is a design note.

### 4.2 Implement `Messages` domain + simplest broadcast
One audience type (e.g., huddl attendees), one delivery channel. Send via existing `Notifications` infrastructure if possible.

### 4.3 Workspace Messages tab UI
Drafts / scheduled / sent lists, audience preview before send.

---

## Phase 5 — Auth polish

### 5.1 Two-column sign-in/sign-up layout
Marketing aside with the prototype's copy variants. Forms still hit existing AshAuthentication actions.

### 5.2 Organize → sign-in → workspace handoff
Anonymous click on `Organize` routes to sign-in then back to `/organize` (or `/organize?intent=create-huddl`).

---

## Cross-cutting

These run alongside every phase rather than as standalone tickets unless something falls through.

- **Mobile pass per phase** — stacked 16:9 cards, hamburger menu where auth controls hide, search collapse.
- **API-first check** — every workspace operation reachable via Ash action with actor; controllers/UI stay thin.
- **Test coverage** — feature tests in `test/features/` per surface; integration over unit.

---

## Open questions to resolve as we go

- Does `/` become marketing/landing or stay as huddl discovery? (1.1)
- Combined results: new route or absorb into `/`? (1.2)
- Followed groups — do we want this association at all? (2.2)
- Invites resource vs. reusing waitlist + join approvals? (2.4)
- Calendar — sync, iCal, or just a view? (3.8)
- Messages — operational (organizer → audience) only, or any social messaging? (4.1)
