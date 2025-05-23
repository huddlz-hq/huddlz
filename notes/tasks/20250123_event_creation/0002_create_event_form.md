# Task: Create Event Form

## Context
- Part of feature: Event Creation (Huddlz)
- Sequence: Task 2 of 6
- Purpose: Build a LiveView form that allows owners/organizers to create huddlz for their groups

## Task Boundaries
- In scope: 
  - LiveView component for event creation
  - Form with all event fields
  - Dynamic field visibility based on event type
  - Basic form validation feedback
  - Success/error handling
- Out of scope: 
  - Access control (handled in next task)
  - Event listing/display
  - RSVP functionality
  - Edit/delete functionality

## Current Status
- Progress: 0%
- Blockers: Requires Task 1 completion (Huddl resource updates)
- Next steps: Begin implementation after Task 1 verification

## Requirements Analysis
- Form should be accessible from group page
- Only show to owners/organizers (UI level, real auth in next task)
- Event type selection should show/hide relevant location fields
- Virtual link field only shown for virtual/hybrid events
- Date/time pickers for start and end times
- Private event checkbox only for public groups

## Implementation Plan
- Create new LiveView for event creation
- Build form using Phoenix form helpers
- Add JavaScript hooks for dynamic field visibility
- Connect to Ash changeset/actions
- Handle success with redirect to group page

## Implementation Checklist
1. [ ] Create new LiveView module for event creation
2. [ ] Add route for event creation (e.g., /groups/:group_id/huddlz/new)
3. [ ] Build form with title and description fields
4. [ ] Add date/time inputs for starts_at and ends_at
5. [ ] Add event type selector (in_person, virtual, hybrid)
6. [ ] Add physical_location field (shown for in_person/hybrid)
7. [ ] Add virtual_link field (shown for virtual/hybrid)
8. [ ] Add is_private checkbox (only for public groups)
9. [ ] Implement dynamic field visibility based on event type
10. [ ] Add form submission handling with Ash action
11. [ ] Add success message and redirect to group page
12. [ ] Add error handling and display
13. [ ] Add "Create Huddl" button on group page (visible to all for now)
14. [ ] Style form with existing app styling patterns

## Related Files
- lib/huddlz_web/live/huddl_form_live.ex (new)
- lib/huddlz_web/router.ex
- lib/huddlz_web/live/group_live.ex (add button)

## Definition of Done
- Form renders with all required fields
- Event type selection dynamically shows/hides location fields
- Form submits and creates huddl in database
- Success redirects to group page
- Errors are displayed to user
- Form follows existing app styling

## Quality Assurance

### AI Verification (Throughout Implementation)
- Run appropriate tests after each checklist item
- Run `mix format` before committing changes
- Verify compilation with `mix compile` regularly

### Human Verification (Required Before Next Task)
- After completing the entire implementation checklist, ask the user:
  "I've completed task 2 (Create Event Form). Could you please verify the implementation by:
   1. Running the application (`mix phx.server`)
   2. Navigating to a group page
   3. Clicking 'Create Huddl' and testing the form
   4. Creating a test event and verifying it saves
   If everything looks good, I'll proceed to the next task (Task 3: Implement Access Control)."

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

## Next Task
- Next task: 0003_implement_access_control
- Only proceed to the next task after:
  - All checklist items are complete
  - All tests are passing
  - Code is properly formatted
  - Changes have been committed
  - User has verified and approved the implementation