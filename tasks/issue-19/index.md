# Issue #19: Update to cucumber 0.2.0

**GitHub Issue**: https://github.com/mwoods79/huddlz/issues/19
**Created**: 2025-05-24 14:05:00
**Branch**: feature/issue-19-cucumber-upgrade

## Original Requirements
This version has shared steps. It would be great to refactor some of the tests into shared modules.

## Requirements Analysis

### User Problem (from discovery conversation)
The current test suite has two main issues:
1. **Duplicated step definitions** across multiple feature test files
2. **Inconsistent patterns** causing developers to "thrash on implementation" for common tasks

The real goal is **establishing standard testing patterns**, not just eliminating duplication. For example, checking flash messages - developers shouldn't have to figure out the implementation each time.

### Key Insights from Discovery
- **Example Need**: "Then I should see 'foobar' in the flash" - a standard way to check flash messages
- **Organization**: Initial categories of "resources" (data setup) and "UI" (interactions/assertions)
- **Philosophy**: Let patterns emerge as we develop a more sophisticated step library
- **Flexibility**: OK to change existing step definitions as long as behavior is preserved
- **Dependency**: PhoenixTest (issue #20) should be implemented first for consistent LiveView/dead view testing

### Target Users
- Developers writing new tests (need consistent patterns)
- Developers debugging test failures (need clear, standard steps)
- Team maintaining the test suite long-term

### Success Criteria
- [ ] Successfully upgrade from cucumber 0.1.0 to 0.2.0
- [ ] Create shared steps that establish standard testing patterns
- [ ] Reduce implementation thrashing for common test scenarios
- [ ] All existing tests continue to pass
- [ ] New tests are easier to write using shared vocabulary

### Technical Approach
1. Upgrade the cucumber dependency
2. Identify common patterns in step definitions
3. Create shared modules for common functionality
4. Refactor existing tests to use shared modules
5. Ensure all tests pass with the new structure

## Task Breakdown

### Task 1: Upgrade cucumber dependency
**File**: tasks/01-upgrade-dependency.md
**Status**: pending
**Estimate**: 0.5 hours

Update mix.exs to use cucumber 0.2.0, run mix deps.get, and ensure the project compiles.

### Task 2: Create shared authentication steps module
**File**: tasks/02-shared-auth-steps.md
**Status**: pending
**Estimate**: 1 hour

Extract common authentication steps ("I am signed in as", user creation) into a shared module.

### Task 3: Create shared navigation and UI steps module
**File**: tasks/03-shared-ui-steps.md
**Status**: pending
**Estimate**: 1 hour

Extract common UI interaction steps (clicking links, seeing content, navigation) into a shared module.

### Task 4: Refactor existing step files
**File**: tasks/04-refactor-step-files.md
**Status**: pending
**Estimate**: 2 hours

Update all existing step definition files to use the new shared modules and remove duplicated code.

### Task 5: Documentation and cleanup
**File**: tasks/05-documentation.md
**Status**: pending
**Estimate**: 0.5 hours

Document the new shared module pattern and update any test-related documentation.

## Progress Tracking
**STATUS: IN PROGRESS**

- [x] Task 1: Upgrade cucumber dependency (completed to 0.4.0)
- [x] Task 2: Create shared authentication steps module
- [x] Task 3: Create shared navigation and UI steps module
- [x] Task 4: Refactor existing step files
- [ ] Task 5: Documentation and cleanup

## GitHub Sync Points
- Planning complete: 2025-05-24 14:05:00
- Last sync: Never
- Next sync: After issue #20 is complete

## Dependency Note
During discovery, determined that PhoenixTest (issue #20) should be implemented first.
PhoenixTest will standardize testing patterns across LiveView and dead views,
providing a better foundation for shared cucumber steps.

## Technical Notes

### Common Patterns Identified
1. **User Management**: "the following users exist:" appears in multiple files
2. **Authentication**: "I am signed in as {string}" is duplicated
3. **Navigation**: Multiple files have navigation and clicking steps
4. **Assertions**: Common patterns for "I should see" and content verification
5. **Magic Link Flow**: Email and confirmation steps are repeated

### Shared Module Structure
- `test/support/cucumber/`
  - `shared_auth_steps.ex` - User creation, authentication
  - `shared_ui_steps.ex` - Navigation, clicking, content assertions
  - `shared_email_steps.ex` - Magic link and email-related steps