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

## Image Ratio

Huddl and group cover imagery should use one predictable crop:

- Cover image: `16:9`
- Result cards: same `16:9` source image
- Mobile cards: stack image above content to preserve `16:9`
- Future group avatar/icon, if needed: separate `1:1` asset

This keeps event and group images predictable across desktop cards, mobile cards, detail pages, and organizer surfaces.

## Navigation

Public discovery belongs in search. The desktop header should avoid redundant `Groups` and `Create` links and use:

- `huddlz`
- `Organize`
- Global search
- Auth controls

`Organize` requires sign-in. After authentication, it should route to an organizer workspace rather than directly to a single creation form.

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
