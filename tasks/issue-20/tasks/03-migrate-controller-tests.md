# Task 3: Migrate Remaining Tests

**Status**: completed
**Started**: 2025-01-25 09:32
**Completed**: 2025-01-25 22:20

## Objective
Migrate all remaining tests (controller and LiveView) to use PhoenixTest exclusively.

## Requirements

1. **Controller Tests**
   - Migrate all controller test files
   - Remove Phoenix.ConnTest imports
   - Use PhoenixTest patterns throughout

2. **LiveView Tests**
   - Migrate all LiveView test files
   - Remove Phoenix.LiveViewTest imports
   - Use PhoenixTest for all interactions

3. **Integration Tests**
   - Update any integration tests
   - Ensure consistent patterns
   - Remove any remaining conditionals

## Files to Migrate

### Controller Tests
- [x] `test/huddlz_web/controllers/page_controller_test.exs` - Empty/commented, no migration needed
- [x] `test/huddlz_web/controllers/error_html_test.exs` - Direct render tests, no migration needed
- [x] `test/huddlz_web/controllers/error_json_test.exs` - Direct render tests, no migration needed

### LiveView Tests
- [x] `test/huddlz_web/live/admin_live_test.exs` - Already using PhoenixTest
- [x] `test/huddlz_web/live/group_live_test.exs` - MIGRATED
- [x] `test/huddlz_web/live/huddl_live_test.exs` - MIGRATED
- [x] `test/huddlz_web/live/huddl_live/new_test.exs` - MIGRATED
- [x] `test/huddlz_web/live/huddl_live/show_test.exs` - MIGRATED
- [x] `test/huddlz_web/live/huddl_search_test.exs` - MIGRATED

### Integration Tests
- [x] `test/integration/magic_link_signup_test.exs` - MIGRATED TO PHOENIXTEST & PASSING
- [x] `test/integration/signup_flow_test.exs` - MIGRATED TO PHOENIXTEST & PASSING

## Acceptance Criteria

- [x] All tests use PhoenixTest exclusively
- [x] No Phoenix.ConnTest imports remain (except in support files)
- [x] No Phoenix.LiveViewTest imports remain
- [x] All tests pass (210 tests, 0 failures)
- [x] Consistent patterns throughout

## Notes

- This completes the migration
- Focus on consistency
- Document any remaining patterns that need attention