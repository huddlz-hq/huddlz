# Task: Implement RSVP System

## Context
- Part of feature: Event Creation (Huddlz)
- Sequence: Task 5 of 6
- Purpose: Allow users to RSVP to huddlz and track attendance count

## Task Boundaries
- In scope: 
  - RSVP action for users
  - Track RSVP count on huddlz
  - Show RSVP button/status on event display
  - Reveal virtual link after RSVP
  - Basic RSVP tracking (user has RSVPed or not)
- Out of scope: 
  - Displaying attendee lists
  - RSVP cancellation
  - Waitlists or capacity limits
  - RSVP deadlines

## Current Status
- Progress: 100%
- Blockers: None
- Current activity: Completed

## Requirements Analysis
- Users can RSVP to events they have access to
- Track which users have RSVPed (many-to-many)
- Increment/track RSVP count on huddl
- Show RSVP status on event cards
- Virtual link becomes visible after RSVP
- No RSVP deadline enforcement

## Implementation Plan
- Create RSVP join table/resource
- Add RSVP action to Huddl
- Update event display with RSVP button
- Implement virtual link reveal logic
- Update RSVP count tracking

## Implementation Checklist
1. [x] Create HuddlAttendee resource (join table between huddl and user)
2. [x] Add has_many :attendees relationship to Huddl
3. [x] Add has_many :rsvps relationship to User
4. [x] Create RSVP action on Huddl resource
5. [x] Add RSVP button to event display component
6. [x] Implement RSVP handling in LiveView
7. [x] Show RSVP status (button vs "You're attending")
8. [x] Update rsvp_count when users RSVP
9. [x] Reveal virtual_link after successful RSVP
10. [x] Add authorization check for RSVP (must have event access)
11. [x] Prevent duplicate RSVPs from same user
12. [x] Generate and run migrations
13. [x] Test RSVP flow end-to-end

## Related Files
- lib/huddlz/communities/huddl_attendee.ex (new)
- lib/huddlz/communities/huddl.ex
- lib/huddlz/accounts/user.ex
- lib/huddlz_web/components/event_card.ex
- lib/huddlz_web/live/huddlz_live.ex
- lib/huddlz_web/live/group_live.ex

## Definition of Done
- Users can RSVP to accessible events
- RSVP count is tracked and displayed
- Users see their RSVP status on events
- Virtual links appear after RSVP
- No duplicate RSVPs allowed
- Authorization is properly enforced

## Quality Assurance

### AI Verification (Throughout Implementation)
- Run appropriate tests after each checklist item
- Run `mix format` before committing changes
- Verify compilation with `mix compile` regularly

### Human Verification (Required Before Next Task)
- After completing the entire implementation checklist, ask the user:
  "I've completed task 5 (Implement RSVP System). Could you please verify the implementation by:
   1. Running the application (`mix phx.server`)
   2. RSVPing to a public event
   3. Checking the RSVP count updates
   4. Verifying virtual link appears after RSVP
   If everything looks good, I'll proceed to the next task (Task 6: Add Event Search)."

## Progress Tracking
- [x] Created HuddlAttendee resource as join table between huddls and users
- [x] Added attendees relationship to Huddl and rsvps relationship to User
- [x] Implemented RSVP action on Huddl using custom change for better control
- [x] Created HuddlLive.Show view with full RSVP UI functionality
- [x] Updated visible_virtual_link calculation to only show links after RSVP
- [x] Added comprehensive authorization checks to prevent unauthorized RSVPs
- [x] Implemented duplicate RSVP prevention logic
- [x] Generated and ran migrations for huddl_attendees table
- [x] Created comprehensive unit tests for RSVP functionality
- [x] Created LiveView tests for UI interactions
- [x] All 180 tests passing

## Commit Instructions
- Make atomic commits after completing logical units of work
- Before finishing the task, ensure all changes are committed
- Follow commit message standards in CLAUDE.md
- Update the Session Log with commit details

## Session Log
- January 23, 2025 - Started task planning...
- May 24, 2025 - Starting implementation of this task...
- May 24, 2025 - Created HuddlAttendee resource with RSVP and cancel_rsvp actions
- May 24, 2025 - Added attendees relationship to Huddl resource and RSVP action
- May 24, 2025 - Added rsvps relationship to User resource
- May 24, 2025 - Created HuddlLive.Show LiveView for displaying individual huddl details with RSVP functionality
- May 24, 2025 - Updated visible_virtual_link calculation to only show links to users who have RSVPed
- May 24, 2025 - Refactored RSVP action to use manage_relationship for proper Ash patterns
- May 24, 2025 - Added HuddlAttendee to Communities domain and generated migrations
- May 24, 2025 - Successfully ran migrations to create huddl_attendees table
- May 24, 2025 - Fixed RSVP action to use custom change instead of manage_relationship for better control
- May 24, 2025 - Updated tests to reflect new RSVP requirement for virtual link visibility
- May 24, 2025 - All tests passing for RSVP functionality, implementation complete
- May 24, 2025 - Created comprehensive test suite with 9 unit tests and 8 LiveView tests
- May 24, 2025 - All 180 tests in the codebase passing, RSVP feature fully integrated

## Next Task
- Next task: 0006_add_event_search
- Only proceed to the next task after:
  - All checklist items are complete
  - All tests are passing
  - Code is properly formatted
  - Changes have been committed
  - User has verified and approved the implementation