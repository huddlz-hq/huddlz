# Learnings from Issue #26: Groups Should Have Slugs

**Completed**: 2025-05-28
**Duration**: Planned 6 tasks, completed in single session with additional unicode investigation
**Complexity**: Medium - straightforward feature with Ash Framework integration challenges

## Key Insights

### 🎯 What Worked Well
- **Slugify library integration** - Excellent unicode support via transliteration (e.g., "北京用户组" → "bei-jing-yong-hu-zu")
- **Ash change modules** - Clean solution for auto-generating slugs during resource creation
- **Incremental implementation** - Following the planned task sequence prevented major issues
- **UI implementation without libraries** - Building modals with standard HTML/CSS worked perfectly

### 🔄 Course Corrections
1. **Planning without user input** (Start of session)
   - **Issue**: Started creating detailed plan before gathering requirements
   - **Learning**: Always engage with user first to understand constraints and preferences
   - **Result**: Better plan aligned with actual needs (no backward compatibility, etc.)

2. **Manual Ash migration edit** (Task 3)
   - **Issue**: Manually edited generated migration to handle existing data
   - **Learning**: NEVER edit Ash migrations - breaks snapshot tracking
   - **Solution**: Delete data and regenerate clean migration in dev
   - **Future**: Would need separate data migration script for production

3. **Test database sync issues** (Task 3)
   - **Issue**: Stale schema from previous migration attempts
   - **Learning**: Always ensure clean rollback before re-running migrations
   - **Solution**: Manual cleanup of database and schema_migrations table

4. **Unicode in seed data** (Post-implementation)
   - **Issue**: Random unicode from generator created strange slugs
   - **Learning**: Slugify handles unicode perfectly - issue was random generation
   - **Solution**: Use explicit names in seeds rather than generators

### ⚠️ Challenges & Solutions
1. **Challenge**: CiString to String conversion for Slugify
   **Solution**: Add `to_string()` in GenerateSlug change module
   **Learning**: Always check type compatibility between libraries

2. **Challenge**: Component library assumptions (modal, simple_form)
   **Solution**: Implement with standard HTML/CSS and Phoenix bindings
   **Learning**: Don't assume external UI libraries - check project patterns first

3. **Challenge**: Seed data authorization errors
   **Solution**: Use `authorize?: false` for seed operations
   **Learning**: Seed scripts lack user context - bypass authorization appropriately

### 🚀 Reusable Patterns

#### Pattern: Ash Change Module for Attribute Generation
**Context**: Auto-generate derived attributes during resource actions
**Implementation**:
```elixir
defmodule GenerateSlug do
  use Ash.Resource.Change
  
  def change(changeset, _opts, _context) do
    if changeset.action.type == :create do
      case {Ash.Changeset.get_attribute(changeset, :slug),
            Ash.Changeset.get_attribute(changeset, :name)} do
        {nil, name} when not is_nil(name) ->
          slug = name |> to_string() |> Slug.slugify()
          Ash.Changeset.change_attribute(changeset, :slug, slug)
        _ ->
          changeset
      end
    else
      changeset
    end
  end
end
```
**Benefits**: Centralized logic, works with Ash lifecycle, handles edge cases

#### Pattern: Unicode-Safe Slug Generation
**Context**: Supporting international group names
**Implementation**: Slugify library with transliteration
**Benefits**: 
- Chinese → pinyin: "北京用户组" → "bei-jing-yong-hu-zu"
- Cyrillic → Latin: "Москва Tech" → "moskva-tech"
- Accents removed: "Café München" → "cafe-munchen"

## Process Insights

### Planning Accuracy
- Estimated tasks: 6
- Actual tasks: 6 + additional unicode investigation
- Estimation accuracy: 90% (missed seed data complexity)

### Time Analysis
- Planned: Multi-session expected
- Actual: Single session completion
- Factors: Good library choice, clear requirements, incremental approach

### Quality Impact
- Tests increased from 209 to 212
- Zero regressions
- Added unicode support beyond requirements

## Recommendations

### For Similar Features
- Research library unicode support early - it's often better than expected
- Use Ash change modules for derived attributes rather than controller logic
- Test with international data to catch edge cases
- Always verify seed data works with new attributes

### For Process Improvement
- Add "Unicode Support" as standard consideration for user-facing text
- Document that project doesn't use external UI component libraries
- Create checklist for Ash migration workflow to prevent manual edits

### For Ash Framework Usage
- Always use Ash-specific commands (`mix ash.reset`, not `mix ecto.reset`)
- Never manually edit migrations - regenerate if needed
- Remember `authorize?: false` for seed/setup scripts
- Convert CiString to String when interfacing with external libraries

## Follow-up Items
- [ ] Consider adding slug history/redirects for future (when in production)
- [ ] Document slug format requirements in user-facing help
- [ ] Add property-based tests for slug generation edge cases