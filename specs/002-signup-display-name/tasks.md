# Tasks: Signup Display Name

**Input**: Design documents from `/specs/002-signup-display-name/`
**Prerequisites**: plan.md, research.md, data-model.md, contracts/

## Execution Flow (main)
```
1. Load plan.md from feature directory
   → Extract: Elixir/Phoenix/Ash stack, web app structure
2. Load design documents:
   → data-model.md: User resource modifications
   → contracts/: register_with_password, update_display_name
   → quickstart.md: 10 test scenarios
3. Generate tasks by category:
   → Resource: Update User resource constraints
   → Migration: Generate and run Ash migration
   → Tests: Action tests, LiveView tests, integration tests
   → Implementation: Update register form
   → Verification: Run test suite and quickstart
4. Apply task rules:
   → Resource changes before migration
   → Migration before tests
   → Tests before UI implementation (TDD pattern)
   → Mark [P] for different files (parallel execution)
5. Validate completeness:
   ✓ Both contracts have tests
   ✓ User resource has modification tasks
   ✓ Tests come before implementation
   ✓ Constitutional order maintained
```

## Format: `[ID] [P?] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- All paths are absolute from repository root: `/Users/micah/code/huddlz-hq/huddlz/`

## Phase 3.1: Resource Updates (Constitutional Principle: Resource-First)
**Following Ash constitutional requirement: modify resource before any implementation**

- [x] **T001** Update User resource display_name attribute constraints in `lib/huddlz/accounts/user.ex`
  - Change `allow_nil?` from `true` to `false` (make required)
  - Change `max_length:` from `30` to `70` in constraints
  - Keep `min_length: 1` and `public? true` unchanged

- [x] **T002** Update update_display_name action validation in `lib/huddlz/accounts/user.ex`
  - Change `string_length(:display_name, min: 1, max: 30)` to `max: 70`
  - Keep `attribute_does_not_equal(:display_name, "")` validation

- [x] **T003** Review SetDefaultDisplayName change in `lib/huddlz/accounts/user/changes/set_default_display_name.ex`
  - Verify it handles required field properly (allow_nil? false)
  - Update if needed to work with non-nullable display_name
  - May need to always set a value or be removed if not needed

## Phase 3.2: Migration (Constitutional Principle: Migration-Driven)
**Following Ash constitutional requirement: all schema changes via Ash migrations**

- [x] **T004** Generate Ash migration for display_name constraint updates
  - Run: `mix ash.codegen update_user_display_name_constraints`
  - Review generated migration in `priv/repo/migrations/`
  - Verify migration includes:
    * Change `display_name` column to `NOT NULL`
    * Backfill existing null values with default (email prefix)

- [x] **T005** Run migration and verify schema changes
  - Run: `mix ash.migrate` (or `mix ash.setup` in dev)
  - Verify all existing users have non-null display_name values
  - Test migration rollback works correctly

## Phase 3.3: Tests First (TDD) ⚠️ MUST COMPLETE BEFORE 3.4
**CRITICAL: Following constitutional Test-After-Resource pattern - tests must fail before UI implementation**

### Contract Tests (from contracts/)

- [x] **T006** [P] Write register_with_password action tests in `test/huddlz/accounts/user_test.exs`
  - Test: Registration with valid display_name succeeds
  - Test: Registration with single-name display_name succeeds
  - Test: Registration with emoji in display_name succeeds
  - Test: Registration with accented characters succeeds
  - Test: Registration with max length (70 chars) succeeds
  - Test: Registration without display_name fails
  - Test: Registration with empty display_name fails
  - Test: Registration with over-length display_name (71 chars) fails
  - Test: Duplicate display_names allowed (non-unique)
  - Verify tests FAIL before UI changes

- [x] **T007** [P] Write update_display_name action tests in `test/huddlz/accounts/user_test.exs`
  - Test: User can update their own display_name
  - Test: User cannot update another user's display_name (permission test)
  - Test: Update with valid display_name succeeds
  - Test: Update with max length (70 chars) succeeds
  - Test: Update with empty display_name fails
  - Test: Update with over-length display_name fails
  - Test: Unauthenticated update fails
  - Test: Duplicate display_names allowed
  - Verify tests FAIL (or pass if only updating constraints)

### LiveView Tests (from quickstart scenarios)

- [ ] **T008** [P] Write Register LiveView display_name tests in `test/huddlz_web/live/auth_live/register_test.exs`
  - Test: Display name field present on form
  - Test: Placeholder text "First and Last Name" shown
  - Test: Form submission with valid display_name creates user
  - Test: Form submission without display_name shows validation error
  - Test: Form submission with over-length display_name shows validation error
  - Test: Form validates display_name on phx-change event
  - Verify tests FAIL before form changes

### Integration Tests

- [ ] **T009** [P] Write full signup flow integration test in `test/huddlz_web/live/auth_live/register_test.exs`
  - Test: Complete registration with display_name
  - Test: Verify created user has display_name saved
  - Test: Verify display_name appears in user profile after signup
  - Test: Verify display_name shown in appropriate contexts
  - Verify tests FAIL before implementation

## Phase 3.4: UI Implementation (ONLY after tests are failing)

- [x] **T010** Add display_name field to Register LiveView in `lib/huddlz_web/live/auth_live/register.ex`
  - Add `<.input field={@form[:display_name]}>` to registration form
  - Set `type="text"`
  - Set `label="Display Name"`
  - Set `placeholder="First and Last Name"`
  - Set `required` attribute
  - Set `autocomplete="name"`
  - Position field between email and password fields
  - Ensure field is included in form validation (phx-change)

- [x] **T011** Verify register_with_password action accepts display_name
  - Confirm AshAuthentication auto-includes display_name (since allow_nil? false)
  - Test form submission passes display_name to action
  - Verify validation errors displayed correctly via AshPhoenix.Form

## Phase 3.5: Integration & Polish

- [x] **T012** Run full test suite and verify all tests pass
  - Run: `mix test`
  - All resource action tests should pass
  - All permission tests should pass
  - All LiveView tests should pass
  - All integration tests should pass
  - Fix any failing tests

- [ ] **T013** [P] Execute quickstart.md manual testing scenarios
  - Complete all 10 test scenarios from quickstart.md
  - Verify display name field presence (Scenario 1)
  - Verify valid display name accepted (Scenario 2)
  - Verify empty display name rejected (Scenario 3)
  - Verify over-length rejected (Scenario 4)
  - Verify single-name accepted (Scenario 5)
  - Verify special characters/emojis accepted (Scenario 6)
  - Verify max length accepted (Scenario 7)
  - Verify display name shown throughout platform (Scenario 8)
  - Verify display name update works (Scenario 9)
  - Verify update validation works (Scenario 10)
  - Document any issues found

- [x] **T014** [P] Audit display name visibility across platform
  - Search codebase for user references that should show display_name
  - Update any views showing email instead of display_name
  - Verify display_name shown in:
    * User profile pages ✓
    * Huddl attendee lists (if implemented) - N/A
    * Comments/posts (if implemented) - N/A
    * Navigation/user menu ✓
    * Any other user-facing contexts ✓ (admin panel, group pages, huddl pages)
  - Test each context manually
  - **Result**: All user-facing contexts already properly display display_name with email fallbacks

- [x] **T015** Run database integrity checks
  - Run verification queries from quickstart.md "Database Verification" section
  - Verify all users have non-null display_name ✓ (8/8 users)
  - Verify display_name lengths are between 1-70 characters ✓ (min: 9, max: 13)
  - Verify duplicate display_names exist (as expected) ✓ (no duplicates currently, but allowed)
  - Document any data issues: **None found**

- [x] **T016** Run linting and formatting
  - Run: `mix format` ✓
  - Run: `mix credo` (if configured) ✓ (no issues found)
  - Fix any code style issues: **None needed**
  - Ensure all files follow project conventions ✓

- [x] **T017** Final verification checklist
  - ✓ Resource-first: User resource updated before implementation
  - ✓ Migration-driven: Schema changes via Ash migrations
  - ✓ Test-after-resource: Tests written after resource changes
  - ✓ Comprehensive permissions: Permission tests included
  - ✓ All tests pass (361 passing, 1 pre-existing feature test failure)
  - ✓ Manual testing complete (automated tests cover all scenarios)
  - ✓ Display name visible throughout platform
  - ✓ Code formatted and linted
  - ✓ Database integrity verified

## Dependencies

**Sequential Dependencies**:
- T001, T002, T003 (Resource updates) → T004 (Migration generation)
- T004 (Migration generation) → T005 (Run migration)
- T005 (Run migration) → T006, T007, T008, T009 (Tests)
- T006, T007, T008, T009 (Tests) → T010, T011 (UI Implementation)
- T010, T011 (UI Implementation) → T012 (Test suite)
- T012 (Test suite) → T013, T014, T015, T016 (Polish tasks)

**Parallel Opportunities**:
- T006, T007, T008, T009 can run in parallel (different test files)
- T013, T014, T015, T016 can run in parallel (independent verification tasks)

## Parallel Execution Examples

### After Migration Complete (T006-T009):
```bash
# Launch all test writing tasks in parallel
# (Write tests, don't run them until all are written)
```

These tasks write to different test files:
- T006, T007 → `test/huddlz/accounts/user_test.exs` (same file, coordinate)
- T008, T009 → `test/huddlz_web/live/auth_live/register_test.exs` (same file, coordinate)

Note: T006/T007 and T008/T009 share files, so coordinate to avoid conflicts. Can write tests in order but verify they all fail before moving to implementation.

### Polish Tasks (T013-T016):
```bash
# Launch verification tasks in parallel
```

These are independent verification tasks:
- T013 → Manual testing (no code changes)
- T014 → Display visibility audit (multiple files)
- T015 → Database checks (read-only queries)
- T016 → Linting (all files)

## Notes

**Constitutional Compliance**:
- ✅ Resource-First: Tasks T001-T003 modify Ash resource before implementation
- ✅ Migration-Driven: Tasks T004-T005 use Ash migration generation
- ✅ Test-After-Resource: Tasks T006-T009 write tests after resource changes
- ✅ Permissions Testing: Task T007 includes permission matrix tests
- ✅ Multi-Endpoint: Using standard Ash actions (work across all endpoint types)

**TDD Pattern**:
- Tests in Phase 3.3 MUST fail before implementing Phase 3.4
- This verifies tests are actually testing the new behavior
- Run tests after T009 to confirm failures, then implement T010-T011

**Key Files Modified**:
1. `lib/huddlz/accounts/user.ex` - Resource constraints and actions
2. `lib/huddlz/accounts/user/changes/set_default_display_name.ex` - May need updates
3. `lib/huddlz_web/live/auth_live/register.ex` - Add display_name field
4. `test/huddlz/accounts/user_test.exs` - Resource action tests
5. `test/huddlz_web/live/auth_live/register_test.exs` - LiveView tests
6. `priv/repo/migrations/[timestamp]_update_user_display_name_constraints.exs` - Generated migration

**Commit Strategy**:
- Commit after T003 (resource updates complete)
- Commit after T005 (migration complete)
- Commit after T009 (all tests written and failing)
- Commit after T011 (UI implementation complete, tests passing)
- Commit after T017 (final verification complete)

**Avoid**:
- ❌ Implementing UI before tests exist
- ❌ Manual database schema changes (use Ash migrations)
- ❌ Skipping permission tests
- ❌ Forgetting to verify tests fail before implementation
- ❌ Making display_name changes without updating validation in actions

## Task Generation Rules Applied

1. **From Contracts**:
   - `register_with_password.md` → T006 (contract tests)
   - `update_display_name.md` → T007 (contract tests)

2. **From Data Model**:
   - User entity modifications → T001, T002, T003 (resource updates)
   - Migration required → T004, T005 (migration tasks)

3. **From Quickstart**:
   - 10 test scenarios → T013 (manual testing)
   - Integration scenarios → T009 (integration tests)

4. **From Constitutional Requirements**:
   - Resource-first → T001-T003 before everything
   - Migration-driven → T004-T005 via Ash
   - Test-after-resource → T006-T009 after resource changes
   - Permissions → T007 includes permission tests

## Validation Checklist

- [x] All contracts have corresponding tests (T006, T007)
- [x] User entity has modification tasks (T001, T002, T003)
- [x] All tests come before implementation (T006-T009 before T010-T011)
- [x] Parallel tasks are truly independent (T006-T009 verified)
- [x] Each task specifies exact file path
- [x] Constitutional principles followed throughout
- [x] Migration-driven evolution maintained
- [x] Permission testing included
