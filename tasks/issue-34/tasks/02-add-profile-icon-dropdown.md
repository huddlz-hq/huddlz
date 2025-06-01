# Task 2: Add profile icon and dropdown structure

## Status: ✅ Completed

## Description
Add a profile icon to the navbar and implement the basic dropdown structure. Also move the Groups link to the left side.

## Requirements
1. Add generic person SVG icon to the far right of navbar
2. Implement DaisyUI dropdown component attached to the icon
3. Move "Groups" link from right to left side of navbar
4. Ensure responsive behavior works correctly

## Technical Details
- File: `lib/huddlz_web/components/layouts.ex`
- Use DaisyUI dropdown classes: `dropdown dropdown-end`
- Profile icon should use `btn-ghost btn-circle avatar` pattern
- Consider mobile positioning with responsive classes

## Acceptance Criteria
- [ ] Generic person icon appears on far right when logged in
- [ ] Clicking icon shows/hides dropdown menu
- [ ] Groups link is now on the left side of navbar
- [ ] Mobile layout: hamburger (left) → brand → profile (right)
- [ ] Dropdown appears correctly on mobile without going off-screen

## Design Notes
- Use a generic person SVG (can use Heroicons or similar)
- Dropdown should use `dropdown-end` to align right
- Add `z-[1]` to ensure dropdown appears above content
- Consider `max-sm:` prefixes for mobile-specific positioning