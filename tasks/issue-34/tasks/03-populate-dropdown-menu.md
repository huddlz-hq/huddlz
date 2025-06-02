# Task 3: Populate dropdown menu and move items

## Status: ✅ Completed

## Description
Complete the dropdown menu with all required items and move existing navbar items into it.

## Requirements
1. Add "Profile" link pointing to `/profile`
2. Move "Admin Panel" from navbar to dropdown (keep admin-only visibility)
3. Move theme toggle from navbar to dropdown
4. Ensure "Sign Out" link is in dropdown

## Technical Details
- Keep conditional rendering for admin panel: `if @current_user.admin`
- Theme toggle should maintain its current functionality
- Order in dropdown: Profile, Admin Panel (if admin), Theme Toggle, divider?, Sign Out

## Acceptance Criteria
- [ ] Dropdown contains Profile link (top)
- [ ] Admin Panel only shows for admin users in dropdown
- [ ] Theme toggle works from dropdown
- [ ] Sign Out link present in dropdown
- [ ] Original navbar items (admin panel, theme toggle) removed from navbar
- [ ] Dropdown styling matches DaisyUI patterns

## UI Notes
- Consider using dividers between logical sections
- Use `menu menu-sm` classes for dropdown content
- Each item should be wrapped in `<li>` tags
- Theme toggle might need special handling to show current state