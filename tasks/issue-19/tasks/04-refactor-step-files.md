# Task 4: Refactor existing step files

**Status**: completed
**Created**: 2025-05-24 14:05:00
**Started**: 2025-05-30 19:45:00
**Completed**: 2025-05-30 20:10:00

## Purpose
Refactor all existing cucumber step definition files to use the new shared modules, removing all duplicated code.

## Scope

### Must Include
- Update all 7 step definition files to use shared modules
- Remove duplicated step definitions
- Add appropriate imports/use statements
- Ensure all tests continue to pass
- Maintain existing functionality

### Explicitly Excludes
- Adding new test functionality
- Changing test behavior
- Modifying feature files

## Implementation Checklist
- [x] Refactor complete_signup_flow_steps_test.exs
- [x] Refactor create_huddl_steps_test.exs
- [x] Refactor group_management_steps_test.exs
- [x] Refactor huddl_listing_steps_test.exs
- [x] Refactor rsvp_cancellation_steps_test.exs
- [x] Refactor sign_in_and_sign_out_steps_test.exs
- [x] Refactor signup_with_magic_link_steps_test.exs
- [x] Run all tests after each file refactor
- [x] Ensure no step definitions are duplicated

## Technical Details
Files to refactor:
- `test/features/steps/complete_signup_flow_steps_test.exs`
- `test/features/steps/create_huddl_steps_test.exs`
- `test/features/steps/group_management_steps_test.exs`
- `test/features/steps/huddl_listing_steps_test.exs`
- `test/features/steps/rsvp_cancellation_steps_test.exs`
- `test/features/steps/sign_in_and_sign_out_steps_test.exs`
- `test/features/steps/signup_with_magic_link_steps_test.exs`

For each file:
1. Add imports for shared modules
2. Remove duplicated step definitions
3. Ensure remaining steps are file-specific
4. Test the file individually

## Acceptance Criteria
- All step files use shared modules where appropriate
- No duplicated step definitions remain
- All cucumber tests pass
- Code is cleaner and more maintainable
- Each file only contains feature-specific steps

## Dependencies
- Requires: Tasks 2 & 3 (shared modules must exist)
- Blocks: Task 5 (documentation)

## Session Notes
[Will be populated during implementation]