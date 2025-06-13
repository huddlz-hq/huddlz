# Task 1: Add :past read action to Huddl resource

## Objective
Create a new read action that retrieves huddlz with start times in the past.

## Requirements
- Add `:past` read action to the Huddl resource
- Filter for `starts_at < DateTime.utc_now()`
- Apply the same visibility preparation as other read actions
- Sort by `starts_at` descending (newest past events first)

## Implementation Steps
1. Open `lib/huddlz/communities/huddl.ex`
2. Add the new read action after the `:upcoming` action
3. Use a prepare block with dynamic DateTime evaluation
4. Apply visibility filtering
5. Add sorting

## Code Location
- File: `lib/huddlz/communities/huddl.ex`
- Section: actions block, after `:upcoming` action

## Testing Notes
- Verify the action returns only past events
- Ensure DateTime.utc_now() is evaluated at query time, not compile time