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
- Progress: 100%
- Blockers: None
- Current activity: Completed

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
1. [x] Create new LiveView module for event creation
2. [x] Add route for event creation (e.g., /groups/:group_id/huddlz/new)
3. [x] Build form with title and description fields
4. [x] Add date/time inputs for starts_at and ends_at
5. [x] Add event type selector (in_person, virtual, hybrid)
6. [x] Add physical_location field (shown for in_person/hybrid)
7. [x] Add virtual_link field (shown for virtual/hybrid)
8. [x] Add is_private checkbox (only for public groups)
9. [x] Implement dynamic field visibility based on event type
10. [x] Add form submission handling with Ash action
11. [x] Add success message and redirect to group page
12. [x] Add error handling and display
13. [x] Add "Create Huddl" button on group page (visible to all for now)
14. [x] Style form with existing app styling patterns

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
- January 23, 2025 - Resuming implementation work...
- January 23, 2025 - Created HuddlLive.New module with complete form implementation
- January 23, 2025 - Added route for /groups/:group_id/huddlz/new
- January 23, 2025 - Implemented all form fields including dynamic visibility for location fields
- January 23, 2025 - Added form validation and submission handlers
- January 23, 2025 - Added "Create Huddl" button to group page (visible to owners/organizers)
- January 23, 2025 - Fixed compilation errors (changed simple_form to form tag, api->domain)
- January 23, 2025 - Formatted code with mix format
- January 23, 2025 - Created test files (LiveView tests and Cucumber features)
- January 23, 2025 - ISSUE: Form submission not creating huddls - needs debugging
- January 23, 2025 - TODO: Fix form submission, complete tests, verify with browser
- May 23, 2025 - Resumed work to debug form submission issue
- May 23, 2025 - Fixed form submission by adding group_id and creator_id to params
- May 23, 2025 - Fixed dynamic field visibility in validate event handler
- May 23, 2025 - Updated tests to handle HTML-escaped group names and correct validation messages
- May 23, 2025 - Fixed all 19 HuddlLive.New tests - all passing
- May 23, 2025 - All 137 tests passing
- May 23, 2025 - Code formatted with mix format
- May 23, 2025 - Task completed successfully

## Next Task
- Next task: 0003_implement_access_control
- Only proceed to the next task after:
  - All checklist items are complete
  - All tests are passing
  - Code is properly formatted
  - Changes have been committed
  - User has verified and approved the implementation