# Task 4: Create basic profile LiveView

## Status: ✅ Completed

## Description
Create a new LiveView for the user profile page with basic structure and authentication.

## Requirements
1. Create new LiveView module for profile page
2. Add route at `/profile`
3. Require authentication (redirect if not logged in)
4. Set up basic page structure with form

## Technical Details
- Create: `lib/huddlz_web/live/profile_live.ex`
- Add to router: `live "/profile", ProfileLive, :index`
- Use `live_session` with `require_authenticated_user`
- Load current user's data in `mount/3`

## Acceptance Criteria
- [ ] `/profile` route exists and requires authentication
- [ ] Unauthenticated users are redirected to sign-in
- [ ] Page displays current display name
- [ ] Form structure is in place (even if not functional)
- [ ] Page title is appropriate (e.g., "Profile")

## Implementation Notes
- Can follow pattern from other authenticated LiveViews
- Form doesn't need to be functional yet (task 5)
- Focus on structure and authentication flow
- Consider using a simple card layout for the form