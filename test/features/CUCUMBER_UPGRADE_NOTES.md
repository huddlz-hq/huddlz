# Cucumber Upgrade Notes

## Current Version

Using cucumber 0.4.2 which includes the hook execution order fix, ensuring `before_scenario` hooks run reliably before any step definitions.

## Feature Tags

All feature files use these tags:
- `@async` - Enables parallel test execution
- `@database` - Sets up database sandbox for the scenario
- `@conn` - Creates a Phoenix test connection

Example:
```gherkin
@async @database @conn
Feature: My Feature
```

## Hooks

Hooks are defined in `test/features/support/hooks.exs`:

- `@database` hook - Checks out an Ecto sandbox for the test process
- `@conn` hook - Creates a Phoenix test connection with initialized session

## Key Design Decisions

1. **No shared sandbox mode** - Each test gets its own exclusive sandbox checkout, enabling proper isolation for async tests.

2. **Tag-based setup** - Database and connection setup are opt-in via tags, keeping concerns separated.

3. **Hooks handle infrastructure** - Step definitions focus on business logic, not test setup.

## Notes

- Ash's `generate()` function works correctly with the sandbox
- Direct `Repo.insert_all/2` is used in some steps to avoid Ash transaction overhead
- PostgreSQL expects binary UUIDs - use `Ecto.UUID.dump/1` when inserting directly
