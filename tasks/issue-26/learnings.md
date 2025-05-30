# Learnings from Issue #26: Groups Should Have Slugs

## Key Technical Learnings

### 1. Never Manually Edit Ash Migrations
**Mistake**: Manually edited a generated migration to handle existing data.
**Problem**: This breaks Ash's snapshot tracking system, causing schema inconsistencies.
**Solution**: 
- In development: Delete data and regenerate clean migrations
- In production: Use separate data migration scripts
**Learning**: Ash migrations are immutable by design - respect this constraint.

### 2. Ash Framework vs Ecto Commands
**Discovery**: Ash has its own command set that should be used instead of Ecto commands.
- Use `mix ash.reset` not `mix ecto.reset`
- Use `mix ash.migrate` not `mix ecto.migrate`
- Use `mix ash.codegen` to generate migrations from resource changes
**Learning**: Always use Ash-specific commands for Ash projects to maintain consistency.

### 3. Type Conversion for External Libraries
**Issue**: Slugify couldn't handle Ash's CiString type directly.
**Solution**: Convert CiString to regular string with `to_string()` before passing to external libraries.
**Learning**: Be aware of custom Ash types and convert them when interfacing with standard Elixir libraries.

### 4. Test Database Synchronization
**Problem**: Test database retained stale schema from failed migration attempts.
**Root Cause**: Multiple migration attempts left database in inconsistent state.
**Solution**: Manually drop columns/indexes and clean schema_migrations table.
**Prevention**: Always ensure clean rollback before re-running migrations.

### 5. Seed Data Authorization
**Discovery**: Seed scripts require `authorize?: false` when creating data.
**Reason**: Seeds run without authenticated user context.
**Pattern**: `|> Ash.create(authorize?: false)`
**Learning**: Only bypass authorization in seed/setup scripts, never in production code.

## Process Improvements

### 1. Planning Phase Must Include User Dialogue
**Mistake**: Started creating detailed plans without gathering requirements.
**Correction**: Always engage with user during `/plan` phase to understand:
- Backward compatibility needs
- Data migration constraints
- Specific behavior requirements
- Production vs development considerations

### 2. Test-After Approach with Ash
**Constraint**: Can't easily test-first with Ash due to code generation requirements.
**Approach**: 
1. Implement resource changes
2. Generate migrations
3. Write comprehensive tests
**Learning**: Adapt TDD practices to framework constraints while maintaining quality.

### 3. Component Architecture Awareness
**Discovery**: Project uses custom components, not external UI libraries.
**Impact**: Had to replace undefined `modal` and `simple_form` components with standard HTML.
**Learning**: Always check existing component patterns before assuming external libraries.

## Feature-Specific Insights

### 1. Slug Generation Strategy
**Implemented**: Auto-generate from name on create, allow manual override.
**UI Pattern**: 
- Create: Auto-update slug as user types
- Edit: Independent slug field with change warning
**Learning**: Different behaviors for create vs edit improves user experience.

### 2. Unicode Support Excellence
**Discovery**: Slugify handles unicode beautifully through transliteration:
- "Café München" → "cafe-munchen"
- "北京用户组" → "bei-jing-yong-hu-zu"
**Learning**: Don't assume limitations - test library capabilities thoroughly.

### 3. Route Parameter Naming
**Decision**: Use `:group_slug` instead of just `:slug` for clarity.
**Benefit**: Self-documenting routes that are easier to understand.
**Pattern**: `/groups/:group_slug/huddlz/:id`

### 4. Relationship Loading for Slugs
**Requirement**: Huddls need to load their group relationship to display slugs.
**Solution**: Add `Ash.Query.load(:group)` where needed.
**Learning**: Think about data requirements when changing primary identifiers.

## Testing Insights

### 1. Test Data Generation
**Problem**: Random unicode from StreamData caused unpredictable slugs.
**Solution**: Use predictable names in tests while keeping unicode test cases separate.
**Learning**: Balance randomization with predictability for stable tests.

### 2. Flexible Test Assertions
**Problem**: Exact href matching broke when switching from IDs to slugs.
**Solution**: Test for presence of elements rather than exact URLs.
**Learning**: Write resilient tests that survive implementation changes.

### 3. Comprehensive Test Coverage
**Achievement**: Added specific unicode handling tests beyond basic functionality.
**Result**: 262 tests covering edge cases and international support.
**Learning**: Go beyond happy path - test international use cases.

## Architecture Patterns

### 1. Ash Resource Changes
**Pattern**: Create dedicated change modules for reusable logic.
```elixir
defmodule GenerateSlug do
  use Ash.Resource.Change
  
  def change(changeset, _opts, _context) do
    # Implementation
  end
end
```
**Learning**: Encapsulate business logic in change modules for reusability.

### 2. Custom Read Actions
**Pattern**: Use `Ash.Query.for_read(:action_name, %{args})` for custom queries.
**Example**: `get_by_slug` action with `get? true` for single record retrieval.
**Learning**: Leverage Ash's action system instead of custom queries.

### 3. Form State Management
**Challenge**: Managing dynamic slug generation while allowing overrides.
**Solution**: Track manual edits with socket assigns and conditional updates.
**Learning**: Phoenix LiveView excels at complex form interactions.

## Documentation Discoveries

### 1. Puppeteer Login Flow
**Challenge**: Magic link authentication in development environment.
**Documented Process**:
1. Request magic link
2. Navigate to /dev/mailbox
3. Click email row (not mailto link)
4. Copy/navigate to magic link URL
**Learning**: Document non-obvious development workflows for future sessions.

### 2. UI Implementation Evolution
**Journey**: From modal-based editing to dedicated edit page.
**Reason**: Simplified slug field behavior and improved user experience.
**Learning**: Don't hesitate to refactor UI when it improves clarity.

## Summary of Best Practices

1. **Respect Framework Constraints**: Work with Ash's patterns, not against them
2. **Type Safety**: Handle custom types when interfacing with external libraries
3. **User-Centric Design**: Different behaviors for create vs edit operations
4. **Comprehensive Testing**: Include edge cases and international scenarios
5. **Clear Documentation**: Capture non-obvious workflows for future reference
6. **Flexible Architecture**: Use framework features (changes, actions) for clean code
7. **Process Discipline**: Always gather requirements before planning

## What Went Well

- Successfully implemented slug feature with zero regressions
- Excellent unicode support discovered and tested
- Clean integration with existing permission model
- Comprehensive test coverage (262 tests)
- All quality gates passing
- UI provides clear feedback and warnings
- Documentation captured for future development

## Areas for Future Consideration

- Production data migration strategies for Ash projects
- Automated testing of magic link authentication flows
- Potential for slug history/redirects for changed slugs
- SEO implications of slug changes
- Performance impact of slug lookups vs UUID lookups