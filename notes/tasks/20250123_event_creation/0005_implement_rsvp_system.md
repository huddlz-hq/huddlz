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
- Progress: 0%
- Blockers: Requires Task 4 completion (Event display)
- Next steps: Begin implementation after Task 4 verification

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
1. [ ] Create HuddlAttendee resource (join table between huddl and user)
2. [ ] Add has_many :attendees relationship to Huddl
3. [ ] Add has_many :rsvps relationship to User
4. [ ] Create RSVP action on Huddl resource
5. [ ] Add RSVP button to event display component
6. [ ] Implement RSVP handling in LiveView
7. [ ] Show RSVP status (button vs "You're attending")
8. [ ] Update rsvp_count when users RSVP
9. [ ] Reveal virtual_link after successful RSVP
10. [ ] Add authorization check for RSVP (must have event access)
11. [ ] Prevent duplicate RSVPs from same user
12. [ ] Generate and run migrations
13. [ ] Test RSVP flow end-to-end

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
- Next task: 0006_add_event_search
- Only proceed to the next task after:
  - All checklist items are complete
  - All tests are passing
  - Code is properly formatted
  - Changes have been committed
  - User has verified and approved the implementation