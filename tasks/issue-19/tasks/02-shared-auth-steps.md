# Task 2: Create shared authentication steps module

**Status**: completed
**Created**: 2025-05-24 14:05:00
**Started**: 2025-05-26
**Completed**: 2025-05-26

## Purpose
Create a shared module containing common authentication-related step definitions that are currently duplicated across multiple test files.

## Scope

### Must Include
- Create SharedAuthSteps module with common authentication steps
- Implement "the following users exist:" step
- Implement "I am signed in as {string}" step
- Ensure proper use of cucumber 0.2.0 shared steps feature
- Add appropriate imports and module structure

### Explicitly Excludes
- Refactoring existing test files (that's task 4)
- Non-authentication related steps
- Changing authentication logic

## Implementation Checklist
- [x] Create directory structure: ~~`test/support/cucumber/`~~ `test/features/steps/`
- [x] Create `shared_auth_steps.ex` file
- [x] Implement shared "the following users exist:" step definition
- [x] Implement shared "I am signed in as {string}" step definition
- [x] Add proper module documentation
- [x] Test that the shared module can be used correctly

## Technical Details
- Module location: `test/features/steps/shared_auth_steps.ex`
- Should use new cucumber 0.2.0 shared steps syntax
- Must handle both User creation patterns (Ash.Seed vs generate)
- Include necessary imports (Phoenix.LiveViewTest, etc.)
- Consider context preservation patterns

## Acceptance Criteria
- SharedAuthSteps module exists and compiles
- Module contains both target step definitions
- Module follows Elixir conventions
- Module is properly documented
- Can be imported and used in other step files

## Dependencies
- Requires: Task 1 (cucumber 0.2.0 upgrade)
- Blocks: Task 4 (refactoring existing files)

## Session Notes
[Will be populated during implementation]