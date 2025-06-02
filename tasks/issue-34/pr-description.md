## Summary
This PR fixes a critical bug where users were getting new random display names on every login and adds user profile management functionality. Users can now update their display names through a dedicated profile page, accessed via a profile dropdown in the navbar.

Closes #34

## Changes
- Fixed display name persistence bug by removing `:display_name` from upsert_fields in the sign_in_with_magic_link action
- Refactored display name generation logic into a reusable Ash change module
- Added profile icon with dropdown menu to navbar (includes Profile, Admin Panel for admins, and Sign Out)
- Implemented `/profile` page for users to manage their display name
- Moved Groups link to left side of navbar and theme toggle to profile dropdown (logged-in user perk)
- Added comprehensive tests including regression test for the display name bug

## Testing
- Run `mix test` to execute all tests (285 tests, 0 failures)
- Manual testing:
  1. Sign in with magic link and verify display name persists across logins
  2. Click profile icon in navbar to access dropdown menu
  3. Navigate to /profile and update display name
  4. Verify mobile responsiveness of navbar and dropdown
- Feature tests cover profile management scenarios
- Regression test ensures display name bug doesn't reoccur

## Learnings
- Ash Framework's `upsert_fields` should only include fields that need updating on every operation
- Using Ash change modules for conditional logic improves code organization and testability
- Strategic UI decisions (like making theme toggle a logged-in perk) can encourage user engagement

## Screenshots
- Homepage with profile icon in navbar
- Profile dropdown menu showing user info and navigation options
- Profile settings page with display name editing
- Success message after updating display name