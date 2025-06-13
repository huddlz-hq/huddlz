# Task 2: Add authorization policies for :past action

## Objective
Configure authorization policies for the new `:past` read action to ensure proper access control.

## Requirements
- Add policy for `:past` action in the policies block
- Mirror the authorization rules from `:upcoming` action
- Allow access to:
  - Public huddls in public groups
  - Any huddl in groups where user is a member
  - Admins (via existing bypass)

## Implementation Steps
1. Locate the policies block in `lib/huddlz/communities/huddl.ex`
2. Add new policy after the `:upcoming` policy
3. Use the same authorization checks:
   - `Huddlz.Communities.Huddl.Checks.PublicHuddl`
   - `Huddlz.Communities.Huddl.Checks.GroupMember`

## Code Location
- File: `lib/huddlz/communities/huddl.ex`
- Section: policies block, after policy for `:upcoming`

## Testing Notes
- Verify non-members cannot see past events in private groups
- Verify members can see past events in their groups
- Verify everyone can see past events in public groups