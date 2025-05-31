# Cucumber 0.4.0 Upgrade Notes

## Changes Made

### 1. Removed @async tags from feature files
- All feature files had `@async @database @conn` tags
- Removed `@async` to prevent concurrent test execution issues
- Removed `@database` since sandbox setup moved to step definitions

### 2. Created database helper module
- Created `test/features/support/database_helper.exs`
- Provides `ensure_sandbox/0` function for consistent sandbox setup
- Handles both new checkouts and existing ownership

### 3. Updated shared auth steps
- Replaced `generate()` with direct database inserts to avoid transaction issues
- Used `Repo.insert_all/2` with proper UUID binary formatting
- Added `ensure_sandbox()` call at the beginning of user creation step

### 4. Updated all step definitions
- Added `import CucumberDatabaseHelper` to all step definition modules that need database access
- Added `ensure_sandbox()` calls in steps that visit pages or create data
- Key files updated:
  - `shared_ui_steps.exs` - for page visits
  - `shared_auth_steps.exs` - for user creation
  - `huddl_listing_steps.exs` - for test data setup
  - `rsvp_cancellation_steps.exs` - for test data setup

### 5. Simplified hooks
- Removed complex sandbox setup from `hooks.exs`
- Kept only the `@conn` tag hook for Phoenix connection setup

## Key Issues Resolved

1. **Sandbox Ownership Errors**: Cucumber 0.4.0 runs each scenario in a separate process, making shared context difficult. Solved by ensuring sandbox in each step that needs it.

2. **Ash Transaction Errors**: Ash's `generate()` function spawns processes for transactions. Replaced with direct database operations.

3. **UUID Format Errors**: PostgreSQL expects binary UUIDs. Used `Ecto.UUID.dump/1` to convert string UUIDs to binary format.

## Remaining Failures

3 tests are failing due to missing UI elements:
- RSVP cancellation tests can't find "Cancel RSVP" button
- One test expects "You're attending!" text that isn't present

These appear to be actual application issues, not test infrastructure problems.