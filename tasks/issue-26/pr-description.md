## Summary
Replaces UUID-based URLs for groups with human-readable slugs to improve user experience and URL shareability. Groups are now accessible via URLs like `/groups/phoenix-elixir-meetup` instead of `/groups/123e4567-e89b-12d3-a456-426614174000`.

Closes #26

## Changes
- Added Slugify library for robust slug generation with unicode support
- Updated Group resource with slug attribute and auto-generation logic
- Migrated all routes from UUID to slug-based patterns
- Implemented slug editing with URL change warnings
- Added comprehensive unicode support and testing
- Updated seed data to use meaningful group names

## Key Implementation Details
- Slugs are auto-generated from group names using Ash change modules
- Full unicode transliteration support (e.g., "北京用户组" → "bei-jing-yong-hu-zu")
- Unique constraint enforced at database level
- Edit form shows warning when changing slugs
- No backward compatibility (as requested - not in production)

## Testing
- Run the app: `mix phx.server`
- Create a group and see slug auto-generation
- Try unicode names like "Café München" or "北京用户组"
- Edit a group and change the slug (see warning)
- Navigate using new slug-based URLs

### Test Coverage
- 212 tests passing (added 3 new unicode tests)
- All Cucumber feature tests passing
- Comprehensive slug generation and validation tests
- Edge cases covered (empty slugs, collisions, unicode)

## Learnings
1. **Ash Migration Integrity**: Never manually edit Ash-generated migrations - it breaks snapshot tracking. Always regenerate for clean implementation.
2. **Unicode Excellence**: The Slugify library provides excellent international support through transliteration, making the feature globally accessible.

## Screenshots
Example slugs generated:
- "Phoenix Elixir Meetup" → `/groups/phoenix-elixir-meetup`
- "Café München" → `/groups/cafe-munchen` 
- "北京用户组" → `/groups/bei-jing-yong-hu-zu`