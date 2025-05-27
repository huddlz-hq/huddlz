# Issue #26: Groups Should Have Slugs

## Overview
Replace UUID-based URLs for groups with human-readable slugs to improve user experience and URL shareability.

**Current State**: Groups are referenced by UUID (e.g., `/groups/123e4567-e89b-12d3-a456-426614174000`)
**Desired State**: Groups referenced by slug (e.g., `/groups/phoenix-elixir-meetup`)

## Requirements

### Core Requirements
1. **Slug Generation**
   - Use Slugify library for consistent slug generation
   - Generate slugs automatically from group names
   - Slugs must be globally unique
   - Allow users to provide custom slugs on collision

2. **URL Structure**
   - Change group routes from `/groups/:id` to `/groups/:slug`
   - Nested routes: `/groups/:group_slug/huddlz/:id`
   - No backward compatibility needed (not in production)

3. **User Experience**
   - On create: Slug field auto-updates as user types name
   - On edit: Slug doesn't auto-change with name
   - Show validation error on slug collision
   - Warn users when changing slug that URLs will break

4. **Permissions**
   - Only group owner can edit group details (including slug)
   - Follows existing permission model

## Technical Decisions

### Slug Library
- **Slugify** (https://hex.pm/packages/slugify)
- Most popular Elixir slug library
- Supports Unicode transliteration
- Customizable separators

### Implementation Approach
1. Add Slugify dependency to mix.exs
2. Update Group resource with slug attribute
3. Generate Ash migration after resource update
4. Update routes and LiveViews to use slugs
5. Update UI forms for slug input/editing
6. Write comprehensive tests

### No Data Migration Needed
- Not in production yet
- No existing data to migrate
- Clean implementation

## Task Breakdown

### Task 1: Add Slugify Dependency
- Add `{:slugify, "~> 1.3"}` to mix.exs
- Run `mix deps.get`
- Verify library works as expected

### Task 2: Update Group Resource
- Add slug attribute to Group resource
- Configure as unique identity
- Add slug to create_group and update_details actions
- Implement slug generation on create
- Allow manual slug override

### Task 3: Generate Ash Migration
- Run `mix ash.codegen add_slug_to_groups`
- Review generated migration
- Run `mix ash.migrate`

### Task 4: Update Routes and LiveViews
- Change router from `:id` to `:slug`
- Update all LiveView mount/handle_params
- Add get_by_slug action to Group resource
- Update group loading logic
- Handle not found errors

### Task 5: Update UI Forms
- Add slug field to group creation form
- Auto-update slug as name is typed (create only)
- Add slug field to group edit form
- Add warning about URL changes when editing slug
- Update all links to use slugs

### Task 6: Comprehensive Testing
- Test slug generation from various names
- Test uniqueness validation
- Test collision handling
- Test all user flows with slugs
- Test error cases
- Feature tests for complete scenarios

## Success Criteria

1. Groups have unique, URL-friendly slugs
2. All group URLs use slugs instead of UUIDs
3. Users can customize slugs on collision
4. Slug editing works with appropriate warnings
5. All tests pass
6. No regression in existing functionality

## Implementation Notes

### Slug Format
- Lowercase alphanumeric with hyphens
- Generated from group name using Slugify
- Example: "Phoenix Elixir Meetup!" → "phoenix-elixir-meetup"

### Uniqueness Handling
- Validation error on collision
- User provides custom slug
- No auto-generation of alternatives (per requirements)

### Form Behavior
- Create: Slug auto-updates with name changes
- Edit: Slug field independent of name
- Warning message when editing existing slug

## Testing Strategy

### After Implementation
1. Unit tests for slug validation
2. Integration tests for slug uniqueness
3. LiveView tests for form behavior
4. Feature tests for complete workflows
5. Error handling tests

### Test Scenarios
- Valid slug generation
- Unicode character handling
- Collision detection
- Custom slug input
- Edit slug warning
- Navigation with slugs
- Invalid slug handling