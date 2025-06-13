# Task 3: Write feature tests for viewing past huddlz

## Objective
Create comprehensive Cucumber tests to verify the `:past` action works correctly with proper authorization.

## Requirements
- Create new feature file: `test/features/view_past_huddlz.feature`
- Test scenarios:
  - Viewing past huddlz as a member
  - Viewing past huddlz in public groups
  - Authorization denial for non-members in private groups
  - Correct filtering (only past events, no future events)
  - Proper sorting (newest past events first)

## Implementation Steps
1. Create `test/features/view_past_huddlz.feature`
2. Create step definitions in `test/features/step_definitions/view_past_huddlz_steps.exs`
3. Use existing test helpers for:
   - Creating users, groups, and huddlz
   - Setting past/future dates
   - Asserting results

## Test Data Setup
- Create huddlz with various start times:
  - 1 day ago
  - 1 week ago
  - 1 month ago
  - 1 hour from now (should not appear)

## Code Location
- Feature file: `test/features/view_past_huddlz.feature`
- Step definitions: `test/features/step_definitions/view_past_huddlz_steps.exs`

## Testing Notes
- Use `Timex` or similar for date manipulation if available
- Ensure consistent timezone handling (UTC)