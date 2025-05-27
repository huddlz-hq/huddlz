# Session Notes - Issue #26: Groups Should Have Slugs

## Session Start: Planning Phase

### 🔄 Course Correction: Planning Process
**Issue**: Started creating a detailed plan without gathering user input first
**Learning**: During `/plan` phase, MUST engage with user to understand requirements before creating any plan documents
**Action**: Deleted premature planning, now gathering requirements through discussion

## Requirements Gathering

### User-Provided Requirements:
- ✅ No backwards compatibility needed
- ✅ Generate migration via Ash AFTER updating resource
- ✅ Slugs are globally unique
- ✅ Slugs generated based on group name
- ✅ On collision, user can provide custom slug
- ✅ Research slug library (slugify mentioned)
- ✅ Not in production - no data migration concerns
- ✅ Slugs can be edited when editing group

### Additional Clarifications:
1. **Collision Handling**:
   - On create: Slug field auto-updates as user types name
   - On edit: Slug doesn't auto-change
   - Show normal validation error on collision
   - No auto-generation of alternatives needed

2. **Permissions**:
   - Only group owner can edit group (including slug)
   - This aligns with current permission model

3. **Slug Library**:
   - Find most popular Elixir slug library (by stars)
   - Unicode support nice to have, not required

4. **Routes**:
   - Keep `/groups/:slug` pattern
   - Nested: `/groups/:group_slug/huddlz/:id`

5. **Actions**:
   - Add slug to both `create_group` and `update_details` actions
   - On update: warn users that changing slug breaks existing URLs

### Testing Strategy:
- Can't easily test-first with Ash due to code generation
- After Ash migration, write comprehensive tests
- Test all functionality end-to-end

### Slug Library Research:
- **Slugify** (by jayjun) is the most popular
- Supports Unicode transliteration
- Customizable separators
- GitHub: https://github.com/jayjun/slugify
- Hex: https://hex.pm/packages/slugify

### Implementation Order:
1. Add Slugify dependency
2. Update Group resource with slug field
3. Generate Ash migration
4. Update routes and LiveViews
5. Update UI for slug input/editing
6. Write comprehensive tests

### Plan Created Successfully
Based on user requirements and discussion:
- Created index.md with complete feature overview
- Created 6 focused task files
- No backward compatibility (not in production)
- Using Slugify library for slug generation
- Slugs editable with warning about breaking URLs
- Only owners can edit groups
- Test after Ash migration, not before

### Initial Analysis
- Reviewed GitHub issue #26: "slugs should be displayed in the url for groups instead of uuids"
- Analyzed current group implementation
- Groups currently use UUID in URLs (e.g., `/groups/123e4567-e89b-12d3-a456-426614174000`)
- Need to implement human-readable slugs (e.g., `/groups/phoenix-elixir-meetup`)

### Key Findings
1. Group resource located at `lib/huddlz/communities/group.ex`
2. Groups use `:ci_string` for names (case-insensitive)
3. Current routes in router use `:id` parameter
4. LiveView files need updates for slug-based routing
5. No existing slug implementation in the codebase

### Design Decisions Made
1. Use parameterized slug format (lowercase, hyphenated)
2. Make slug a unique identity in Ash Framework
3. Auto-generate slug from group name
4. Handle conflicts with number suffix
5. Consider backward compatibility for existing URLs

### Tasks Created
Created 6 tasks covering:
1. Adding slug attribute to Group resource
2. Creating and running migration
3. Implementing slug generation logic
4. Updating routes and LiveViews
5. Updating UI links and navigation
6. Optional backward compatibility

## Next Steps
Ready to begin implementation with Task 1: Add Slug Attribute to Group Resource

## Planning Complete
- Created comprehensive task breakdown (6 tasks)
- Created individual task files with detailed requirements
- Created feature branch: `feature/issue-26-group-slugs`
- Ready for implementation phase

### Task Summary:
1. **Add Slug Attribute** - Add slug field to Group resource
2. **Create Migration** - Database changes and data migration
3. **Slug Generation Logic** - Auto-generate and ensure uniqueness
4. **Update Routes/LiveViews** - Change from ID to slug-based routing
5. **Update UI Links** - Fix all link generation in templates
6. **Backward Compatibility** - Optional UUID support for transition