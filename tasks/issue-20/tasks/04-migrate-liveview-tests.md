# Task 4: Remove Old Test Approaches Entirely

## Objective
Completely remove Phoenix.ConnTest and Phoenix.LiveViewTest from the codebase, ensuring PhoenixTest is the only approach.

## Requirements

1. **Remove Old Imports**
   - Search entire codebase for Phoenix.ConnTest
   - Search entire codebase for Phoenix.LiveViewTest
   - Remove all imports and uses
   - Update test helper files

2. **Clean Test Helpers**
   - Remove ConnTest/LiveViewTest from ConnCase
   - Remove any legacy test utilities
   - Ensure only PhoenixTest helpers remain
   - Update any shared test modules

3. **Verify Complete Removal**
   - No references to old test modules
   - No mixed approaches in any file
   - All tests still pass
   - One consistent approach throughout

## Files to Check/Update

- [ ] `test/support/conn_case.ex`
- [ ] `test/support/data_case.ex`
- [ ] `test/test_helper.exs`
- [ ] Any other test support files

## Verification Steps

```bash
# These should return no results:
grep -r "Phoenix.ConnTest" test/
grep -r "Phoenix.LiveViewTest" test/
grep -r "import Phoenix.ConnTest" test/
grep -r "use Phoenix.ConnTest" test/
```

## Acceptance Criteria

- [ ] Zero references to Phoenix.ConnTest
- [ ] Zero references to Phoenix.LiveViewTest
- [ ] All tests use PhoenixTest exclusively
- [ ] Test helpers cleaned up
- [ ] No possibility of using old approaches

## Notes

- This ensures we have ONE way to test
- No confusion for future developers
- Clear, consistent approach throughout