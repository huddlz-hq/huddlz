# Task 1: Fix display name bug + regression test

## Status: ✅ Completed

## Description
Fix the bug where users get a new random display name every time they log in, and add a test to prevent regression.

## Requirements
1. Modify `sign_in_with_magic_link` action to only set display name on initial user creation
2. Ensure existing users keep their current display name when logging in
3. Write a test that verifies display name persists across login sessions

## Technical Details
- File: `lib/huddlz/accounts/user.ex`
- Current bug: Lines 111-118 in `sign_in_with_magic_link` action
- The action currently generates a new display name even for existing users

## Acceptance Criteria
- [ ] New users get a random "ColorAnimal123" display name on first sign-in
- [ ] Existing users keep their display name when signing in again
- [ ] Test proves display name doesn't change on subsequent logins
- [ ] All existing tests still pass

## Implementation Notes
- Check if user already has a display_name before generating a new one
- Use the existing `generate_random_display_name/0` function for new users only