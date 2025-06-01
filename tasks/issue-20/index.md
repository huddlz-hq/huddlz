# Issue #20: Use PhoenixTest

## Overview
Replace Phoenix.ConnTest and Phoenix.LiveViewTest with PhoenixTest to eliminate API inconsistencies between LiveView and dead view testing.

## Problem Statement

The current testing approach has a fundamental API inconsistency:
- **LiveView tests**: Return `{:ok, view, html}` tuple, requiring knowledge of when to use regex vs live process messages
- **Dead view tests**: Completely different API (though we don't currently have any)
- **Result**: Conditionals in our Cucumber feature tests to handle these differences

This inconsistency makes tests harder to write, maintain, and understand.

## Solution: PhoenixTest

PhoenixTest provides a single, consistent API for testing both LiveViews and regular controller views, eliminating the need for conditionals and reducing cognitive overhead.

## Implementation Strategy

### Priority: Feature Tests First
The Cucumber step definitions are the main pain point and should be migrated first, as they contain the problematic conditionals.

### Phase 1: Setup & Validation
- Add PhoenixTest dependency
- Create proof-of-concept migration of one feature test
- Validate that it truly simplifies (not adds complexity)
- **Gate**: If POC doesn't simplify, abandon approach

### Phase 2: Feature Test Migration
- Migrate all Cucumber step definitions to PhoenixTest
- Remove LiveView/dead view conditionals
- Ensure all feature tests pass

### Phase 3: Complete Migration
- Migrate remaining controller tests
- Migrate remaining LiveView tests
- Remove Phoenix.ConnTest and Phoenix.LiveViewTest imports entirely

### Phase 4: Cleanup & Documentation
- Remove all references to old testing approaches
- Update documentation
- Ensure ONE way to test going forward

## Critical Constraints

1. **One Way Only**: PhoenixTest must REPLACE, not supplement existing approaches
2. **Simplification Required**: If this adds a third way to test, we abandon it
3. **Complete Migration**: No mixing of approaches - all tests use PhoenixTest
4. **Feature Tests First**: They're the main driver for this change

## Success Criteria

- [x] All Cucumber step definitions use PhoenixTest
- [x] No conditionals for LiveView vs dead view testing
- [x] Phoenix.ConnTest remains only in support files (required by PhoenixTest)
- [x] Phoenix.LiveViewTest completely removed from test files
- [x] All tests pass (209 tests, 0 failures)
- [x] Testing is demonstrably simpler

## Update: PhoenixTest Successfully Adopted

During implementation, we successfully migrated all tests to PhoenixTest, achieving the goal of API consistency across the test suite. Flash messages work correctly with PhoenixTest.

## Implementation Status

✅ **Completed**:
- All 7 Cucumber step files migrated to PhoenixTest
- All 80 LiveView unit tests migrated to PhoenixTest
- All 4 integration tests migrated to PhoenixTest
- Fixed all warnings and credo issues
- All 209 tests passing (one duplicate test removed)

**Final Approach**:
- PhoenixTest adopted for all test files (except error template tests)
- Provides consistent API across LiveView and controller testing
- Phoenix.ConnTest remains in support files (PhoenixTest dependency)

## Connection to Issue #19

This refactoring will make the Cucumber upgrade (issue #19) easier by:
- Removing conditionals from step definitions
- Providing a cleaner API for test interactions
- Simplifying the overall testing approach

## Task Breakdown

1. ✅ **Add PhoenixTest and create POC**
2. ✅ **Migrate Cucumber step definitions**
3. ✅ **Migrate remaining tests**
4. ✅ **Remove old test approaches entirely** (where possible)
5. ✅ **Update documentation**

## Final Resolution

Issue #20 has been successfully completed. PhoenixTest has been adopted throughout the test suite, providing:

- **Consistent API**: All tests use the same patterns for interacting with views
- **Simplified Testing**: No more conditionals for LiveView vs dead views
- **Clean Codebase**: No warnings, all credo checks pass
- **Complete Migration**: 209 tests successfully migrated and passing

The original goal of eliminating API inconsistencies has been achieved.

## Notes

- Main goal: API consistency, not just style consistency
- If we end up with 3 ways to test, we've failed
- Document insights discovered during migration
- Clean refactor to PhoenixTest idioms preferred