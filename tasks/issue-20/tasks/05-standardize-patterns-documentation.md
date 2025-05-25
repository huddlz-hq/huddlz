# Task 5: Update Documentation

## Objective
Update all documentation to reflect PhoenixTest as the single testing approach.

## Requirements

1. **Update Testing Documentation**
   - Update `docs/testing.md` to use PhoenixTest examples
   - Remove references to Phoenix.ConnTest/LiveViewTest
   - Add PhoenixTest patterns and best practices
   - Include migration examples

2. **Update CLAUDE.md**
   - Update test commands section
   - Add PhoenixTest as the standard
   - Remove old testing patterns
   - Include common PhoenixTest patterns

3. **Create Migration Guide**
   - Document common migration patterns
   - Before/after examples
   - Gotchas and solutions
   - Reference for future migrations

## Documentation Updates

- [ ] `docs/testing.md` - Main testing guide
- [ ] `CLAUDE.md` - AI assistant instructions
- [ ] `docs/ash_framework/testing.md` - Ash-specific patterns
- [ ] Create `docs/phoenix_test_migration.md`

## Key Patterns to Document

1. **Basic Navigation and Assertions**
   ```elixir
   session()
   |> visit("/")
   |> assert_has("h1", text: "Welcome")
   ```

2. **Form Interactions**
   ```elixir
   session()
   |> visit("/groups/new")
   |> fill_form("#group-form", name: "Book Club")
   |> click_button("Create")
   |> assert_has(".alert", text: "Group created")
   ```

3. **Authentication**
   ```elixir
   session()
   |> sign_in_as(user)
   |> visit("/protected")
   ```

## Acceptance Criteria

- [ ] All docs use PhoenixTest examples
- [ ] No references to old test approaches
- [ ] Clear patterns documented
- [ ] Migration guide complete
- [ ] Team ready to use PhoenixTest

## Notes

- Emphasize the "one way" principle
- Make it impossible to use old patterns
- Clear, practical examples