# Search and Organize Design Notes

This folder captures high-fidelity design prototypes that can be iterated in plain HTML/CSS before being pulled into the Phoenix UI.

Open the current clickable prototype directly in a browser:

```text
docs/design/search-organize-prototype.html
```

In development, Phoenix also serves the design lab at:

```text
/dev/design
/dev/design/search-organize
```

These routes are mounted only when `:dev_routes` is enabled.

Prototype image assets live in `docs/design/images/` and are served in development from `/dev/design/images/:filename`.

## Search

The global search should optimize for the simplest path:

1. User clicks the search box.
2. User types a query.
3. User presses Enter.
4. Results load.

Advanced controls should not be required before the first search. The focused search state may show lightweight suggestions such as:

- Search all
- Search huddlz
- Search groups
- More filters

The results page can expose more controls because the user has already expressed intent. Current refinements:

- Scope: All, Huddlz, Groups
- City
- Distance
- Date
- Format
- Group topics
- Huddl options
- Sort

For combined huddl/group search, the preferred first product behavior is grouped results. `All` can show Huddlz and Groups as separate sections, which keeps pagination understandable while still giving users one global search entry point.

## Landing Page

The initial landing page should be a usable discovery surface, not a marketing-only page:

- Header pairs the `huddlz` brand with global search.
- Hero copy explains the outcome: find real-life gatherings.
- Primary action focuses search.
- Secondary action is `Organize`, which requires sign-in.
- A featured huddl gives users something concrete to inspect immediately.
- Upcoming cards below the fold show real 16:9 imagery and reinforce what a huddl/group looks like.
- Organizer messaging appears as a practical workspace pitch, not a separate sales page.

## Authentication

Sign-in and sign-up should stay visually connected to discovery:

- Keep the global header and search available.
- Use a compact form as the primary surface.
- Explain the account value in practical terms: faster RSVPs, followed groups, and organizer access.
- Sign-up should feel lightweight and reversible, not like a large onboarding commitment.
- `Organize` should route signed-out users through sign-in before opening organizer tools.
- Signed-in users should see a compact avatar/account menu instead of `Sign Up` / `Sign In`.
- The account menu should expose organizer workspace, profile/preferences, workspace settings, public home, and sign out.

## Organizer Workspace

The organizer experience should be a signed-in workspace, not a public marketing page:

- Use a stable sidebar for `Overview`, `Groups`, `Huddlz`, `Attendees`, `Members`, `Messages`, and `Settings`.
- Keep `Attendees` event-specific: RSVPs, waitlists, check-ins, cancellations, guests, and no-shows for individual huddlz.
- Keep `Members` group-specific: people connected to a group over time, roles, join status, and participation history.
- Use a master-detail layout so organizers can scan lists and inspect the selected operational context without losing navigation.
- Primary actions should be `Create group` and `Create huddl`.
- Settings should be boring and predictable: permissions, defaults, notifications, links, integrations, and account safety.
- User preferences are separate from workspace settings: profile, notifications, discovery defaults, privacy, security, and accessibility belong to the signed-in person.

### Create Huddl

Creating a huddl should be a focused organizer subview:

- Entry point: organizer workspace `Create huddl` action, with signed-out users routed through sign-in first.
- Required basics: title, group, description, date, time, and format.
- Cover upload should preview the same 16:9 crop used by search cards and include a crop tool entry point.
- Address entry should start with a place/address search, then show a matched address, map preview, adjustable pin, latitude, and longitude.
- Publish settings should cover search visibility, RSVP requirement, capacity/waitlist, and reminders.
- Draft and publish actions should stay visible while reviewing the form.

## Member Dashboard

Signed-in users also need a personal surface that is not organizer-focused:

- `My Huddlz` shows upcoming RSVPs, interested/waitlisted huddlz, past attendance, calendar actions, and RSVP changes.
- `My Groups` shows groups the user belongs to, follows, or organizes, with group-level notification controls.
- `Invites` collects huddl invitations, waitlist openings, and group join approvals that need a response.
- `Updates` collects reminders, organizer messages, group announcements, RSVP changes, and unread notifications.
- The account menu should give users quick access to `My Huddlz`, `My Groups`, organizer workspace, preferences, settings, public home, and sign out.

## Image Ratio

Huddl and group cover imagery should use one predictable crop:

- Cover image: `16:9`
- Result cards: same `16:9` source image
- Mobile cards: stack image above content to preserve `16:9`
- Future group avatar/icon, if needed: separate `1:1` asset

This keeps event and group images predictable across desktop cards, mobile cards, detail pages, and organizer surfaces.

The prototype intentionally uses real image files instead of CSS-only placeholders so image cropping, footer art, and card density can be evaluated closer to the eventual product UI.

## Navigation

Public discovery belongs in search. The desktop header should avoid redundant `Groups` and `Create` links and use:

- `huddlz`
- Global search
- `Organize`
- Auth controls

`Organize` requires sign-in. After authentication, it should route to an organizer workspace rather than directly to a single creation form.

Discovery should feel attached to the brand: place global search immediately after the `huddlz` logo. Put `Organize` with the right-side account actions because it is an authenticated workspace entry point, not a public discovery link.

On mobile, the hamburger is used because auth links are hidden. On desktop, the hamburger should stay hidden because explicit auth controls are visible.

## Organizer Workspace

`Organize` should open an authenticated admin shell with side navigation and master-detail views. Suggested sections:

- Overview
- Groups
- Huddlz
- Calendar
- Drafts
- Attendees
- Members
- Messages
- Settings

### Overview

The organizer home should answer what needs attention today:

- Upcoming huddlz
- Total RSVPs
- Groups organized
- Drafts
- Needs attention
- Recent activity
- Quick actions: Create group, Create huddl

### Groups

Group-level administration:

- Groups the user owns or organizes
- Visibility/status
- Member counts
- Organizer roles
- Pending join requests
- Upcoming huddlz
- Actions: edit profile, new huddl, manage organizers, invite members

### Huddlz

Event-level administration:

- Published, draft, canceled, and past huddlz
- Date, group, format, RSVPs, capacity, status
- RSVP health and waitlist
- Actions: edit, view public page, message attendees, duplicate, cancel

### Calendar

Scheduling view across groups:

- Month/week/list views
- Group filter
- Upcoming agenda
- Conflict or needs-attention indicators
- Calendar sync affordance

### Drafts

Unfinished group and huddl work:

- Draft type
- Last edited
- Completion checklist
- Missing required fields
- Actions: continue editing, preview, publish, delete draft

### Attendees

Cross-group RSVP operations. Attendees are connected to huddlz/events.

Useful columns:

- Person
- RSVP status
- Huddl
- Group
- Date
- Guests
- Last activity

Useful filters:

- Group
- Huddl
- Date range
- RSVP status
- Checked in
- Waitlisted
- Needs approval

The attendee detail panel should include RSVP answers, check-in state, organizer notes, attendance history, and actions such as message, mark checked in, or move to waitlist.

### Members

Group membership management. Members are connected to groups, whether or not they RSVP to a specific huddl.

Useful columns:

- Member
- Role
- Groups
- Status
- Joined
- Last active
- Attendance

Useful actions:

- Message
- Change role
- Approve request
- Remove member
- Block

### Messages

Organizer communications hub:

- Direct messages
- Group broadcasts
- Huddl announcements
- Automated reminders
- Audience selector
- Preview before sending

This is for operational organizer communication, not general social chat.

### Settings

Organizer and group defaults:

- Organizer profile
- Notifications
- Team access
- Group defaults
- RSVP defaults
- Integrations
- Billing
- Danger zone

Settings should include defaults such as visibility, RSVP approval, capacity, `16:9` cover ratio, location defaults, reminder schedule, and attendee questions.
