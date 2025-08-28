# Learnings from Issue #34: User Profiles

**Completed**: January 6, 2025
**Duration**: Planned 5 tasks, Actual 5 tasks (with refactoring)
**Complexity**: Medium - Bug fix + New feature

## Key Insights

### 🎯 What Worked Well
- **Test-first approach**: Writing regression tests before fixing the bug ensured we understood the root cause
- **Incremental implementation**: Breaking down into 5 focused tasks made the feature manageable
- **Pattern reuse**: Following existing patterns (like generate_slug.ex) for the change module made code consistent
- **DaisyUI components**: Using dropdown component saved time and ensured mobile responsiveness

### 🔄 Course Corrections
1. **Refactoring to change module**: After initial bug fix, extracted logic to follow established patterns
2. **Theme toggle placement**: Moved from navbar to dropdown as "logged-in user perk" - smart product decision
3. **Profile form complexity**: Used AshPhoenix.Form.submit instead of manual changeset handling for cleaner code

### ⚠️ Challenges & Solutions
1. **Challenge**: Display name bug - users getting new names on every login
   **Solution**: Removed `:display_name` from `upsert_fields` in sign_in_with_magic_link action
   **Learning**: Upsert fields should only include data that should be updated on every operation

2. **Challenge**: Detecting new vs existing users in Ash action
   **Solution**: Check `!changeset.data.id` to determine if user is new
   **Learning**: In Ash, changeset.data contains the existing record (nil id = new record)

3. **Challenge**: Form validation and error handling in LiveView
   **Solution**: Used AshPhoenix.Form.submit with proper error extraction
   **Learning**: AshPhoenix provides cleaner form handling than manual changeset manipulation

### 🚀 Reusable Patterns

#### Pattern: Ash Change Module for Conditional Logic
**Context**: When you need to apply logic conditionally in Ash actions
**Implementation**:
```elixir
defmodule MyApp.Resource.Changes.ConditionalChange do
  use Ash.Resource.Change

  def change(changeset, _opts, %{type: type}) when type in [:create, :specific_action] do
    if condition_met?(changeset) do
      Ash.Changeset.change_attribute(changeset, :field, value)
    else
      changeset
    end
  end

  def change(changeset, _opts, _context), do: changeset
end
```
**Benefits**: Reusable, testable, follows single responsibility principle

#### Pattern: Profile Dropdown Navigation
**Context**: User menu that works on mobile and desktop
**Implementation**:
```heex
<div class="dropdown dropdown-end">
  <label tabindex="0" class="btn btn-ghost btn-circle avatar rounded-full bg-base-300">
    <.icon name="hero-user" class="h-6 w-6" />
  </label>
  <ul tabindex="0" class="menu menu-sm dropdown-content mt-3 z-[1] p-2 shadow bg-base-100 rounded-box w-52">
    <!-- menu items -->
  </ul>
</div>
```
**Benefits**: Mobile-friendly, accessible, consistent with DaisyUI patterns

## Process Insights

### Planning Accuracy
- Estimated tasks: 5
- Actual tasks: 5 + 1 refactoring
- Estimation accuracy: 90% (minor refactoring added)

### Time Analysis
- Planned: ~2-3 hours
- Actual: ~3-4 hours (including refactoring)
- Factors: Additional refactoring to follow patterns, comprehensive testing

## Recommendations

### For Similar Features
- Always check upsert_fields when debugging unexpected data changes
- Use Ash change modules for reusable business logic
- Test mobile dropdown behavior early in implementation
- Consider product implications of feature placement (theme toggle as perk)

### For Process Improvement
- Add "check for existing patterns" as explicit step in task planning
- Include refactoring time buffer for pattern alignment
- Document Ash-specific gotchas (like changeset.data.id checking)

## Follow-up Items
- [ ] Add theme preference to profile page (currently missing)
- [ ] Consider adding more profile fields (bio, avatar, etc.)
- [ ] Add profile completion indicator
- [ ] Document the change module pattern in development patterns