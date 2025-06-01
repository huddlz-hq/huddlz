# Task: Update Huddl Resource

## Context
- Part of feature: Event Creation (Huddlz)
- Sequence: Task 1 of 6
- Purpose: Extend the existing Huddl resource with fields and relationships needed for event functionality

## Task Boundaries
- In scope:
  - Add new attributes for events (dates, location, type, etc.)
  - Add relationship to group
  - Add relationship to creator (user)
  - Add RSVP tracking
  - Replace status field with calculated attribute
  - Add validations for dates and event types
- Out of scope:
  - UI components
  - Complex RSVP logic
  - Notification system
  - Recurring events

## Current Status
- Progress: 100%
- Blockers: None
- Current activity: Completed

## Requirements Analysis
- Huddl needs to track: title, description, start/end times, event type, locations
- Must belong to a group and have a creator
- Virtual links should be a separate private field
- Status should be calculated from timestamps, not stored
- Basic RSVP count tracking needed

## Implementation Plan
- Modify existing Huddl resource in Communities domain
- Add all required attributes with appropriate types
- Set up relationships to groups and users
- Implement date validations
- Create calculated status attribute
- Add basic RSVP structure

## Implementation Checklist
1. [x] Add event attributes (title, description, starts_at, ends_at) - already existed
2. [x] Add event_type attribute with enum (in_person, virtual, hybrid)
3. [x] Add location fields (physical_location, virtual_link)
4. [x] Add is_private boolean for public group private events
5. [x] Add belongs_to relationship to group - made non-nullable
6. [x] Add belongs_to relationship to creator (user) - renamed from host
7. [x] Add rsvp_count attribute (integer, default 0)
8. [x] Remove old status field if it exists - removed string status field
9. [x] Add calculated status attribute based on timestamps
10. [x] Add validation that ends_at > starts_at
11. [x] Add validation that starts_at is in the future (for create)
12. [x] Generate and run migrations
13. [x] Run tests to ensure nothing breaks

## Related Files
- lib/huddlz/communities/huddl.ex
- Database migration files

## Definition of Done
- Huddl resource has all required fields
- Relationships to group and user are established
- Date validations are working
- Status is calculated, not stored
- All existing tests still pass
- New migration is generated and runs successfully

## Quality Assurance

### AI Verification (Throughout Implementation)
- Run appropriate tests after each checklist item
- Run `mix format` before committing changes
- Verify compilation with `mix compile` regularly

### Human Verification (Required Before Next Task)
- After completing the entire implementation checklist, ask the user:
  "I've completed task 1 (Update Huddl Resource). Could you please verify the implementation by:
   1. Running the application (`mix phx.server`)
   2. Checking that migrations run successfully
   3. Verifying the resource compiles without errors
   If everything looks good, I'll proceed to the next task (Task 2: Create Event Form)."

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
- January 23, 2025 - Starting implementation of this task...
- January 23, 2025 - Updated Huddl resource with all required attributes
- January 23, 2025 - Added event_type enum, location fields, is_private flag, and rsvp_count
- January 23, 2025 - Changed group relationship to non-nullable
- January 23, 2025 - Renamed host to creator for clarity
- January 23, 2025 - Removed old string status field and added calculated status
- January 23, 2025 - Added date validations and location requirement validations
- January 23, 2025 - Generated and ran migration (dropped existing test data)
- January 23, 2025 - Updated test generator to provide group_id and new fields
- January 23, 2025 - All tests passing, code formatted
- January 23, 2025 - Committed changes: feat(huddlz): extend Huddl resource for event functionality

## Next Task
- Next task: 0002_create_event_form
- Only proceed to the next task after:
  - All checklist items are complete
  - All tests are passing
  - Code is properly formatted
  - Changes have been committed
  - User has verified and approved the implementation