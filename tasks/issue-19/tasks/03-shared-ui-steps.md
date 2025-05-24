# Task 3: Create shared navigation and UI steps module

**Status**: pending
**Created**: 2025-05-24 14:05:00
**Started**: -
**Completed**: -

## Purpose
Create a shared module containing common UI interaction and navigation step definitions that are currently duplicated across multiple test files.

## Scope

### Must Include
- Create SharedUISteps module for navigation and UI interactions
- Implement "I click {string}" step
- Implement "I should see {string}" step
- Implement "the user clicks the {string} link in the navbar" step
- Implement "the user is on the home page" step
- Add other common UI interaction patterns

### Explicitly Excludes
- Authentication-related steps (covered in task 2)
- Email-related steps
- Complex business logic assertions

## Implementation Checklist
- [ ] Create `test/support/cucumber/shared_ui_steps.ex` file
- [ ] Implement shared navigation step definitions
- [ ] Implement shared clicking/interaction step definitions
- [ ] Implement shared content assertion step definitions
- [ ] Add proper module documentation
- [ ] Ensure all steps handle both conn and live view contexts

## Technical Details
- Module location: `test/support/cucumber/shared_ui_steps.ex`
- Must handle both regular conn-based tests and LiveView tests
- Should include Phoenix.LiveViewTest imports
- Consider parameterized steps for flexibility
- Handle different assertion patterns (content, presence, etc.)

## Acceptance Criteria
- SharedUISteps module exists and compiles
- Contains all identified common UI steps
- Handles both conn and LiveView contexts
- Well documented with usage examples
- Follows consistent naming patterns

## Dependencies
- Requires: Task 1 (cucumber 0.2.0 upgrade)
- Blocks: Task 4 (refactoring existing files)

## Session Notes
[Will be populated during implementation]