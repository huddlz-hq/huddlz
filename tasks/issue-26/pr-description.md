# PR: Add URL-friendly slugs to groups

## Summary

This PR implements human-readable URL slugs for groups, replacing UUID-based routes with friendly URLs like `/groups/phoenix-elixir-meetup`. The implementation includes automatic slug generation from group names with full unicode support, manual slug editing capabilities, and comprehensive test coverage.

## Key Changes

### 1. Slug Generation Infrastructure
- Added Slugify library dependency for robust slug generation
- Created `GenerateSlug` Ash change module that auto-generates slugs on group creation
- Implemented unicode transliteration support ("Café München" → "cafe-munchen")

### 2. Database Schema Updates  
- Added `slug` attribute to Group resource with unique constraint
- Generated Ash migration to add slug column and unique index
- Updated seed data with meaningful group names that generate clean slugs

### 3. Routing & Navigation
- Changed all group routes from `/groups/:id` to `/groups/:slug`
- Updated nested routes to `/groups/:group_slug/huddlz/:id`
- Added `get_by_slug` read action to Group resource
- Updated all internal navigation links throughout the application

### 4. User Interface
- Simplified group creation form - slug auto-generates from name with real-time preview
- Added dedicated edit page (replaced modal) with slug editing capability
- Shows full URL preview (e.g., "http://localhost:4000/groups/my-group")
- Displays warning when editing slug about breaking existing links

### 5. Test Coverage
- Added comprehensive test suite for slug generation and validation
- Created specific unicode handling tests for international support
- All 262 tests passing with zero regressions

## Technical Decisions

1. **No Manual Slug Input on Create**: Since the `GenerateSlug` change uses `force_change_attribute`, we simplified the UI to show only a preview during creation.

2. **Dedicated Edit Page**: Moved from modal-based editing to a dedicated page for better UX and clearer slug editing behavior.

3. **Unicode Support**: Leveraged Slugify's excellent transliteration capabilities for international group names.

4. **No Backward Compatibility**: As requested, no support for old UUID-based URLs since the application is not yet in production.

## Testing Instructions

1. Create a new group and observe slug auto-generation as you type
2. Try unicode characters in group names (e.g., "Café & Co", "北京用户组")
3. Edit an existing group and change the slug - note the warning message
4. Verify all group navigation uses the new slug-based URLs
5. Check that permissions still work correctly (only owners can edit)

## Quality Checklist

- [x] All tests passing (262 tests)
- [x] Code formatted with `mix format`
- [x] Static analysis clean with `mix credo --strict`
- [x] Feature tests passing
- [x] No regressions in existing functionality
- [x] Documentation updated (LEARNINGS.md, CLAUDE.md)

## Breaking Changes

- All group URLs now use slugs instead of UUIDs
- External links to groups will break (acceptable as not in production)

## Screenshots

_Note: Implementation focused on functionality over visual changes. UI remains consistent with existing design._

Fixes #26