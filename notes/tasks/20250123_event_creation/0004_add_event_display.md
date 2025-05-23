# Task: Add Event Display

## Context
- Part of feature: Event Creation (Huddlz)
- Sequence: Task 4 of 6
- Purpose: Display huddlz on group pages and create a main huddlz listing page

## Task Boundaries
- In scope: 
  - Show upcoming huddlz on group pages
  - Create main huddlz search/listing page
  - Display event details (without virtual link)
  - Show event status (upcoming/ongoing/past)
  - Basic event cards/list items
- Out of scope: 
  - RSVP functionality
  - Calendar views
  - Complex filtering (just basic for MVP)
  - Event detail pages

## Current Status
- Progress: 0%
- Blockers: Requires Task 3 completion (Access control)
- Next steps: Begin implementation after Task 3 verification

## Requirements Analysis
- Group pages should list their upcoming huddlz
- Main page should search/list all public huddlz
- Events should show: title, description, date/time, location, type, status
- Virtual links remain hidden until RSVP
- Clear visual distinction between event types
- Chronological ordering (soonest first)

## Implementation Plan
- Add huddlz section to group LiveView
- Create new main huddlz listing LiveView
- Build reusable event display component
- Implement proper queries with access control
- Add basic search/filter functionality

## Implementation Checklist
1. [ ] Create event display component (title, time, location, type indicator)
2. [ ] Add huddlz query to group LiveView (upcoming events for that group)
3. [ ] Display huddlz list on group page
4. [ ] Create main huddlz listing LiveView (/huddlz or update home)
5. [ ] Implement query for all visible public huddlz
6. [ ] Add search functionality by title/description
7. [ ] Display event type with icons/badges (in-person/virtual/hybrid)
8. [ ] Show calculated status (upcoming/ongoing/past)
9. [ ] Hide virtual links in display (show "Link available after RSVP")
10. [ ] Order events chronologically (soonest first)
11. [ ] Add "No upcoming huddlz" empty states
12. [ ] Style event cards to match app design
13. [ ] Add routing for main huddlz page
14. [ ] Update navigation to include huddlz search

## Related Files
- lib/huddlz_web/live/group_live.ex
- lib/huddlz_web/live/huddlz_live.ex (new)
- lib/huddlz_web/components/event_card.ex (new component)
- lib/huddlz_web/router.ex

## Definition of Done
- Huddlz appear on group pages
- Main huddlz search page is functional
- Events display all public information
- Virtual links are hidden
- Search works for public events
- Events are properly ordered
- Access control is respected in queries

## Quality Assurance

### AI Verification (Throughout Implementation)
- Run appropriate tests after each checklist item
- Run `mix format` before committing changes
- Verify compilation with `mix compile` regularly

### Human Verification (Required Before Next Task)
- After completing the entire implementation checklist, ask the user:
  "I've completed task 4 (Add Event Display). Could you please verify the implementation by:
   1. Running the application (`mix phx.server`)
   2. Checking huddlz appear on group pages
   3. Testing the main huddlz search page
   4. Verifying private events don't show publicly
   If everything looks good, I'll proceed to the next task (Task 5: Implement RSVP System)."

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
- Next task: 0005_implement_rsvp_system
- Only proceed to the next task after:
  - All checklist items are complete
  - All tests are passing
  - Code is properly formatted
  - Changes have been committed
  - User has verified and approved the implementation