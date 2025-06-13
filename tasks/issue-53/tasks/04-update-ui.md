# Task 4: Update UI to display huddlz

## Objective
Implement the home page to display both upcoming and past huddlz using the new `:past` action.

## Requirements
- Update `HomeLive` to fetch and display huddlz
- Create sections for:
  - Upcoming huddlz (using `:upcoming` action)
  - Past huddlz (using new `:past` action)
- Display huddl information:
  - Title
  - Description (truncated)
  - Start/end times
  - Event type and location
  - RSVP count
  - Group name

## Implementation Steps
1. Update `lib/huddlz_web/live/home_live.ex`:
   - Add mount callback to load huddlz
   - Fetch both upcoming and past huddlz
   - Handle empty states
2. Update the render function:
   - Add sections for upcoming/past
   - Create huddl cards/list items
   - Add navigation to huddl details
3. Consider pagination for large datasets

## Code Location
- File: `lib/huddlz_web/live/home_live.ex`
- May need to create components in `lib/huddlz_web/components/`

## UI/UX Considerations
- Clear visual distinction between upcoming and past
- Responsive design
- Loading states
- Empty state messages
- Accessibility (ARIA labels, semantic HTML)