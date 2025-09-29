# Tasks: Date Time Selection for Huddl Creation

**Input**: Design documents from `/specs/001-date-time-selection/`
**Prerequisites**: plan.md (required), research.md, data-model.md, contracts/

## Execution Flow (main)
```
1. Load plan.md from feature directory
   → Tech stack: Elixir 1.18, Phoenix 1.8.0, Ash 3.0, LiveView 1.0.9
   → Structure: Phoenix web app with Ash resources
2. Load design documents:
   → data-model.md: Virtual arguments for date/time/duration
   → contracts/: API and LiveView form contracts
   → research.md: Technical decisions (keep existing DB fields)
3. Generate tasks by category:
   → Setup: Verify dependencies, prepare environment
   → Tests: Update existing tests for new form fields
   → Core: Ash resource changes, component creation, LiveView updates
   → Integration: Form validation and calculation logic
   → Polish: Quickstart validation, documentation
4. Apply task rules:
   → Component creation tasks can run in parallel [P]
   → LiveView updates must be sequential (same file)
   → Tests after resource changes (Ash pattern)
5. Number tasks sequentially (T001-T023)
6. Validate completeness:
   → All components defined in contracts
   → Test coverage for new functionality
   → Quickstart scenarios covered
```

## Format: `[ID] [P?] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- Include exact file paths in descriptions

## Path Conventions
- **Resources**: `lib/huddlz/communities/`
- **LiveViews**: `lib/huddlz_web/live/huddl_live/`
- **Components**: `lib/huddlz_web/components/`
- **Tests**: `test/huddlz_web/live/huddl_live/` and `test/features/`

## Phase 3.1: Setup & Preparation
- [X] T001 Verify Ash 3.0 and Phoenix 1.8.0 dependencies in mix.exs
- [X] T002 Run mix deps.get to ensure all dependencies are current
- [X] T003 [P] Run mix format and mix credo to check code standards

## Phase 3.2: Ash Resource Modifications (Constitutional Requirement)
**CRITICAL: Must modify Ash resource FIRST per constitution**
- [X] T004 Add virtual arguments (date, start_time, duration_minutes) to Huddl resource in lib/huddlz/communities/huddl.ex
- [X] T005 Add changeset logic to calculate starts_at and ends_at from virtual arguments
- [X] T006 Update create and update actions to accept new virtual arguments
- [X] T007 Add validation for duration_minutes (min: 15, max: 1440)

## Phase 3.3: Tests First (TDD Pattern) ⚠️ MUST COMPLETE BEFORE 3.4
**Following Test-After-Resource pattern from constitution**
- [X] T008 Update test/huddlz_web/live/huddl_live/new_test.exs for new form fields
- [X] T009 Add test for date picker validation (future dates only) in test/huddlz_web/live/huddl_live/new_test.exs
- [X] T010 Add test for time picker with manual entry in test/huddlz_web/live/huddl_live/new_test.exs
- [X] T011 Add test for duration calculation and end time display in test/huddlz_web/live/huddl_live/new_test.exs
- [X] T012 [P] Update test/features/step_definitions/create_huddl_steps.exs for BDD scenarios

## Phase 3.4: Core Implementation (ONLY after tests are failing)
### Component Creation (Can run in parallel)
- [X] T013 [P] Create date_picker/1 component in lib/huddlz_web/components/core_components.ex
- [X] T014 [P] Create time_picker/1 component with 15-minute increments, 12-hour AM/PM format, and manual entry
- [X] T015 [P] Create duration_picker/1 component with preset options (30m, 1h, 1.5h, 2h, 2.5h, 3h, 4h, 6h)

### LiveView Updates (Must be sequential - same file)
- [X] T016 Replace datetime-local inputs with new components in lib/huddlz_web/live/huddl_live/new.html.heex
- [X] T017 Add end time calculation display in the form template
- [X] T018 Update handle_event("validate", ...) to calculate ends_at from inputs
- [X] T019 Update handle_event("save", ...) to process new form fields

## Phase 3.5: Integration & Validation
- [X] T020 Test form submission with quickstart.md scenarios
- [X] T021 Verify calculated end times are correct across day boundaries
- [X] T022 [P] Test with recurring events to ensure compatibility

## Phase 3.6: Polish & Documentation
- [X] T023 [P] Run mix test to ensure all tests pass
- [X] T024 [P] Run mix format and fix any formatting issues
- [X] T025 Update CHANGELOG.md with feature description
- [X] T026 Verify performance goal (<200ms form interaction)

## Dependencies Graph
```
T001-T003 (Setup)
    ↓
T004-T007 (Ash Resource)
    ↓
T008-T012 (Tests)
    ↓
T013-T015 (Components - parallel)
    ↓
T016-T019 (LiveView - sequential)
    ↓
T020-T022 (Integration)
    ↓
T023-T026 (Polish - parallel)
```

## Parallel Execution Examples

### After Ash Resource Changes (T004-T007):
```bash
# Run all test updates in parallel
mix test test/huddlz_web/live/huddl_live/new_test.exs &
mix test test/features/step_definitions/create_huddl_steps.exs &
wait
```

### Component Creation (T013-T015):
```bash
# Can develop all three components simultaneously
# Each in lib/huddlz_web/components/core_components.ex
# but as separate functions
```

### Final Polish (T023-T026):
```bash
# Run all checks in parallel
mix test &
mix format --check-formatted &
mix credo &
wait
```

## Task Execution Notes

1. **Constitutional Compliance**:
   - Start with Ash resource (T004-T007)
   - Write tests before implementation (T008-T012)
   - No manual database changes

2. **Key Files to Modify**:
   - `lib/huddlz/communities/huddl.ex` - Resource changes
   - `lib/huddlz_web/components/core_components.ex` - New components
   - `lib/huddlz_web/live/huddl_live/new.ex` - LiveView logic
   - `lib/huddlz_web/live/huddl_live/new.html.heex` - Form template

3. **Validation Checklist**:
   - [ ] Date picker prevents past dates
   - [ ] Time allows manual entry beyond 15-min increments
   - [ ] Duration limits enforced (15 min - 24 hours)
   - [ ] End time calculates correctly
   - [ ] Existing tests still pass

4. **No Migration Required**:
   - Using existing starts_at and ends_at fields
   - Virtual arguments don't need database changes
   - Only adding form-level virtual fields to Ash resource

## Success Criteria

The feature is complete when:
1. All tasks T001-T026 are checked off
2. All tests pass (mix test)
3. Form interactions respond in <200ms
4. Quickstart scenarios work correctly
5. No regressions in existing functionality

## Rollback Plan

If issues arise:
1. Revert Ash resource changes (git)
2. Restore original datetime-local inputs
3. Ensure existing huddlz still work
4. Document issues for next iteration