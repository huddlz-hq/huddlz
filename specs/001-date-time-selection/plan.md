
# Implementation Plan: Date Time Selection for Huddl Creation

**Branch**: `001-date-time-selection` | **Date**: 2025-09-29 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-date-time-selection/spec.md`

## Execution Flow (/plan command scope)
```
1. Load feature spec from Input path
   → If not found: ERROR "No feature spec at {path}"
2. Fill Technical Context (scan for NEEDS CLARIFICATION)
   → Detect Project Type from file system structure or context (web=frontend+backend, mobile=app+api)
   → Set Structure Decision based on project type
3. Fill the Constitution Check section based on the content of the constitution document.
4. Evaluate Constitution Check section below
   → If violations exist: Document in Complexity Tracking
   → If no justification possible: ERROR "Simplify approach first"
   → Update Progress Tracking: Initial Constitution Check
5. Execute Phase 0 → research.md
   → If NEEDS CLARIFICATION remain: ERROR "Resolve unknowns"
6. Execute Phase 1 → contracts, data-model.md, quickstart.md, agent-specific template file (e.g., `CLAUDE.md` for Claude Code, `.github/copilot-instructions.md` for GitHub Copilot, `GEMINI.md` for Gemini CLI, `QWEN.md` for Qwen Code or `AGENTS.md` for opencode).
7. Re-evaluate Constitution Check section
   → If new violations: Refactor design, return to Phase 1
   → Update Progress Tracking: Post-Design Constitution Check
8. Plan Phase 2 → Describe task generation approach (DO NOT create tasks.md)
9. STOP - Ready for /tasks command
```

**IMPORTANT**: The /plan command STOPS at step 7. Phases 2-4 are executed by other commands:
- Phase 2: /tasks command creates tasks.md
- Phase 3-4: Implementation execution (manual or via tools)

## Summary
Replace the existing datetime pickers in huddl creation with three separate inputs: date picker, time picker (15-minute increments with manual entry), and duration selector (predefined options from 30 minutes to 6 hours). This improves UX by simplifying event scheduling with standard time blocks.

## Technical Context
**Language/Version**: Elixir 1.18 / OTP 26
**Primary Dependencies**: Phoenix 1.8.0, Ash 3.0, LiveView 1.0.9, AshPostgres 2.0
**Storage**: PostgreSQL via AshPostgres.DataLayer
**Testing**: ExUnit, Phoenix Test 0.6.0, Cucumber 0.4.0 (BDD)
**Target Platform**: Web application (Phoenix LiveView)
**Project Type**: web - Phoenix application with Ash resources
**Performance Goals**: <200ms form interaction response time
**Constraints**: Must maintain existing authorization policies, support recurring events
**Scale/Scope**: Modify existing huddl creation form in LiveView

## Constitution Check
*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Resource-First Development**:
- [x] All features start with Ash resource definitions - Modifying existing Huddl resource
- [x] Resource structure defined before implementation - Will update Huddl resource attributes

**Test-After-Resource Pattern**:
- [x] Tests planned for all resource actions - Will update existing tests after resource changes
- [x] Permission matrix tests included - Maintaining existing permission tests

**Comprehensive Permissions**:
- [x] Permissions matrix documented for all actions - No new actions, maintaining existing policies
- [x] Edge cases identified for testing - Date validation, duration limits covered

**Multi-Endpoint Planning**:
- [x] JSON API endpoints considered - Using existing Huddl API endpoints
- [ ] GraphQL endpoints considered - Not currently implemented
- [ ] MCP tool endpoints considered - Not currently implemented

**Migration-Driven Evolution**:
- [x] All schema changes via Ash migrations - Will generate migration for any attribute changes
- [x] No manual database modifications - Using Ash migration tooling

## Project Structure

### Documentation (this feature)
```
specs/[###-feature]/
├── plan.md              # This file (/plan command output)
├── research.md          # Phase 0 output (/plan command)
├── data-model.md        # Phase 1 output (/plan command)
├── quickstart.md        # Phase 1 output (/plan command)
├── contracts/           # Phase 1 output (/plan command)
└── tasks.md             # Phase 2 output (/tasks command - NOT created by /plan)
```

### Source Code (repository root)
```
lib/
├── huddlz/
│   └── communities/
│       └── huddl.ex              # Ash resource to modify
└── huddlz_web/
    ├── components/
    │   └── core_components.ex    # Shared UI components
    └── live/
        └── huddl_live/
            └── new.ex            # LiveView to modify

test/
├── huddlz_web/
│   └── live/
│       └── huddl_live/
│           └── new_test.exs      # Tests to update
└── features/
    └── step_definitions/
        └── create_huddl_steps.exs # BDD tests to update

priv/
└── repo/
    └── migrations/               # No new migration needed (virtual fields only)
```

**Structure Decision**: Phoenix 1.8 web application with Ash resources. The feature modifies the existing Huddl resource and its LiveView form, following the established project structure with resources in `lib/huddlz/`, LiveViews in `lib/huddlz_web/live/`, and corresponding tests.

## Phase 0: Outline & Research ✅
1. **Extract unknowns from Technical Context** above:
   - ✅ No NEEDS CLARIFICATION items found
   - ✅ Researched existing implementation patterns
   - ✅ Analyzed current datetime handling

2. **Generate and dispatch research agents**:
   - ✅ Researched existing Huddl resource structure
   - ✅ Analyzed LiveView form implementation
   - ✅ Studied component patterns in core_components.ex
   - ✅ Reviewed database schema and migrations

3. **Consolidate findings** in `research.md`:
   - ✅ Documented technical decisions (7 key decisions)
   - ✅ Chose approaches with rationales
   - ✅ Listed alternatives considered

**Output**: ✅ research.md created with all clarifications resolved

## Phase 1: Design & Contracts ✅
*Prerequisites: research.md complete*

1. **Extract entities from feature spec** → `data-model.md`:
   - ✅ Huddl entity modifications documented
   - ✅ Virtual attributes for form inputs defined
   - ✅ Validation rules specified (min 15, max 1440 minutes)
   - ✅ State transitions mapped (input → calculation → persistence)

2. **Generate API contracts** from functional requirements:
   - ✅ Created `/contracts/huddl-create.json` (OpenAPI 3.0)
   - ✅ Created `/contracts/liveview-form.md` (LiveView contract)
   - ✅ Defined request/response schemas
   - ✅ Documented error states

3. **Generate contract tests** (deferred to tasks phase):
   - Will create test file for new form inputs
   - Will assert date/time/duration validation
   - Tests will initially fail (TDD approach)

4. **Extract test scenarios** from user stories:
   - ✅ Created comprehensive quickstart.md
   - ✅ 7 main test scenarios defined
   - ✅ Edge cases documented
   - ✅ Browser testing checklist included

5. **Update agent file incrementally**:
   - ✅ Ran `.specify/scripts/bash/update-agent-context.sh claude`
   - ✅ Added Elixir/Phoenix/Ash tech stack
   - ✅ Updated CLAUDE.md with project context

**Output**: ✅ data-model.md, ✅ /contracts/*, quickstart.md ✅, CLAUDE.md updated ✅

## Phase 2: Task Planning Approach ✅
*This section describes what the /tasks command will do - DO NOT execute during /plan*

**Task Generation Strategy**:
The /tasks command will:
- Load `.specify/templates/tasks-template.md` as base
- Generate tasks from our Phase 1 artifacts:
  - Component creation tasks (date_picker, time_picker, duration_picker)
  - Ash resource modification task (add virtual arguments)
  - LiveView update tasks (form fields, event handlers)
  - Test update tasks (unit and integration)
  - Migration generation task (if needed)

**Ordering Strategy**:
1. Update Ash resource with virtual arguments (foundation)
2. Create picker components in core_components.ex [P]
3. Update LiveView form template
4. Add LiveView event handlers
5. Update existing tests
6. Run integration tests via quickstart
7. Generate migration if any schema changes

**Estimated Output**: 15-20 numbered, ordered tasks in tasks.md

**Task Categories Expected**:
- 3-4 Component tasks (create pickers)
- 2-3 Resource tasks (Ash modifications)
- 3-4 LiveView tasks (form updates)
- 4-5 Test tasks (update existing tests)
- 1-2 Validation tasks (quickstart execution)

**IMPORTANT**: This phase is executed by the /tasks command, NOT by /plan

## Phase 3+: Future Implementation
*These phases are beyond the scope of the /plan command*

**Phase 3**: Task execution (/tasks command creates tasks.md)  
**Phase 4**: Implementation (execute tasks.md following constitutional principles)  
**Phase 5**: Validation (run tests, execute quickstart.md, performance validation)

## Complexity Tracking
*Fill ONLY if Constitution Check has violations that must be justified*

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |


## Progress Tracking
*This checklist is updated during execution flow*

**Phase Status**:
- [x] Phase 0: Research complete (/plan command)
- [x] Phase 1: Design complete (/plan command)
- [x] Phase 2: Task planning complete (/plan command - describe approach only)
- [x] Phase 3: Tasks generated (/tasks command)
- [ ] Phase 4: Implementation complete
- [ ] Phase 5: Validation passed

**Gate Status**:
- [x] Initial Constitution Check: PASS
- [x] Post-Design Constitution Check: PASS
- [x] All NEEDS CLARIFICATION resolved
- [x] Complexity deviations documented (none required)

---
*Based on Constitution v1.0.0 - See `/memory/constitution.md`*
