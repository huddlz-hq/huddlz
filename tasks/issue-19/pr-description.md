## Summary

Upgrades cucumber from 0.1.0 to 0.4.0 and implements shared step definitions to establish standard testing patterns. This eliminates duplication across test files and provides a consistent vocabulary for common testing scenarios.

Closes #19

## Changes

- Upgraded cucumber dependency from ~> 0.1.0 to ~> 0.4.0 (exceeding target 0.2.0)
- Created `SharedAuthSteps` module for authentication patterns (user creation, sign-in)
- Created `SharedUISteps` module for UI interactions (navigation, assertions, forms)
- Refactored all 7 step definition files to use shared modules
- Added comprehensive documentation at `test/features/step_definitions/README.md`
- Added @moduledoc documentation to shared step modules

## Testing

All existing tests continue to pass with the new shared step pattern:
- Run `mix test` to verify all 272 tests pass
- Run `mix credo --strict` to verify zero issues
- Feature tests now use consistent patterns for authentication, navigation, and assertions

Key improvements:
- Flash message checking: `Then I should see "Success!" in the flash`
- Authentication: `Given I am signed in as "alice@example.com"`
- Form interactions: `When I fill in "Name" with "Test Group"`

## Learnings

1. **Documentation should live next to code** - Initially placed README in support directory, but co-locating with step definitions improves discoverability
2. **Shared steps naturally categorize** - Authentication, UI navigation, assertions, and form interactions emerged as clear groupings
3. **Standard vocabulary reduces friction** - Developers no longer need to figure out implementation for common tasks like checking flash messages

## Screenshots

N/A - Testing infrastructure changes only, no UI modifications