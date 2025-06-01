# Task: Implement Access Control

## Context
- Part of feature: Event Creation (Huddlz)
- Sequence: Task 3 of 6
- Purpose: Ensure only group owners and organizers can create events, and enforce visibility rules

## Task Boundaries
- In scope:
  - Authorization checks for event creation
  - Enforce private group = private event rule
  - Implement public group private event option
  - Visibility rules for who can see events
  - Protect virtual link visibility
- Out of scope:
  - RSVP permissions (next tasks)
  - Event editing permissions
  - UI changes (beyond hiding/showing based on permissions)

## Current Status
- Progress: 100%
- Blockers: None
- Next steps: Task completed, ready for Task 4

## Requirements Analysis
- Only owners and organizers can create huddlz
- Private groups can only create private events
- Public groups can create public or private events
- Private events only visible to group members
- Virtual links only visible to future attendees
- Need actor-based authorization in Ash

## Implementation Plan
- Add authorization rules to Huddl resource
- Create custom checks for owner/organizer status
- Implement visibility filters for event queries
- Add virtual link visibility logic
- Update LiveView to check permissions

## Implementation Checklist
1. [x] Add create authorization to Huddl resource (check owner/organizer)
2. [x] Create custom check for owner/organizer status
3. [x] Add change to force is_private=true for private groups
4. [x] Add read authorization based on event/group privacy
5. [x] Create preparation to filter events based on membership
6. [x] Add virtual_link visibility logic (only for attendees)
7. [x] Update event form LiveView to check create permission
8. [x] Hide "Create Huddl" button for non-owners/organizers
9. [x] Add query preparation for public event filtering
10. [x] Test authorization with different user types
11. [x] Ensure private events don't appear in public listings
12. [x] Write tests for access control scenarios

## Related Files
- lib/huddlz/communities/huddl.ex
- lib/huddlz/communities/huddl/checks/ (new checks)
- lib/huddlz_web/live/huddl_form_live.ex
- lib/huddlz_web/live/group_live.ex

## Definition of Done
- Only owners/organizers can access event creation form
- Private groups automatically create private events
- Public groups can choose private or public
- Private events only visible to group members
- Virtual links hidden from non-attendees
- All authorization scenarios have tests

## Quality Assurance

### AI Verification (Throughout Implementation)
- Run appropriate tests after each checklist item
- Run `mix format` before committing changes
- Verify compilation with `mix compile` regularly

### Human Verification (Required Before Next Task)
- After completing the entire implementation checklist, ask the user:
  "I've completed task 3 (Implement Access Control). Could you please verify the implementation by:
   1. Running the application (`mix phx.server`)
   2. Testing as different user types (owner, organizer, member, non-member)
   3. Verifying only owners/organizers see 'Create Huddl' button
   4. Testing private/public event visibility
   If everything looks good, I'll proceed to the next task (Task 4: Add Event Display)."

## Progress Tracking
- Update after completing each checklist item
- Mark items as completed with timestamps
- Document any issues encountered and how they were resolved

## Commit Instructions
- Make atomic commits after completing logical units of work
- Before finishing the task, ensure all changes are committed
- Follow commit message standards in CLAUDE.md
- Update the Session Log with commit details

## Session Log
- January 23, 2025 - Started task planning...
- May 23, 2025 - Starting implementation of access control...
- May 23, 2025 - Created custom authorization checks (GroupOwnerOrOrganizer, GroupMember, PublicHuddl)
- May 23, 2025 - Created change module to force private events for private groups
- May 23, 2025 - Created preparation to filter events based on visibility
- May 23, 2025 - Created calculation for virtual link visibility
- May 23, 2025 - Added authorization policies to Huddl resource
- May 23, 2025 - Updated HuddlLive to pass actor to queries
- May 23, 2025 - Created comprehensive access control tests
- May 23, 2025 - Fixed issue with policies not applying to :upcoming and :search actions
- May 23, 2025 - All tests passing (157 tests, 0 failures)
- May 23, 2025 - Task completed successfully

## Next Task
- Next task: 0004_add_event_display
- Only proceed to the next task after:
  - All checklist items are complete
  - All tests are passing
  - Code is properly formatted
  - Changes have been committed
  - User has verified and approved the implementation