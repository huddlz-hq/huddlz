# Implementation Plan: Signup Display Name

**Branch**: `002-signup-display-name` | **Date**: 2025-10-01 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/002-signup-display-name/spec.md`

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
6. Execute Phase 1 → contracts, data-model.md, quickstart.md, agent-specific template file
7. Re-evaluate Constitution Check section
   → If new violations: Refactor design, return to Phase 1
   → Update Progress Tracking: Post-Design Constitution Check
8. Plan Phase 2 → Describe task generation approach (DO NOT create tasks.md)
9. STOP - Ready for /tasks command
```

**IMPORTANT**: The /plan command STOPS at step 8. Phases 2-4 are executed by other commands:
- Phase 2: /tasks command creates tasks.md
- Phase 3-4: Implementation execution (manual or via tools)

## Summary
This feature enhances the user signup process by making the display name field prominent, required, and properly validated. Users will be guided to enter their first and last name (though single names are accepted), with the display name shown consistently across all platform contexts. The existing User resource already has a display_name attribute, but it needs constraint updates (from 30 to 70 character max, required instead of optional) and the signup form needs to include the field with appropriate guidance.

## Technical Context
**Language/Version**: Elixir 1.15+, Phoenix LiveView 1.0
**Primary Dependencies**: Ash 3.x, AshPhoenix, AshAuthentication, AshPostgres
**Storage**: PostgreSQL via Ash (User resource in Huddlz.Accounts domain)
**Testing**: ExUnit with Ash test helpers
**Target Platform**: Web application (Phoenix LiveView)
**Project Type**: web - Phoenix backend with LiveView frontend
**Performance Goals**: Standard web response times (<200ms for form validation)
**Constraints**:
- Display name max length: 70 characters (updated from 30)
- All printable characters including emojis allowed
- Non-unique (multiple users can share same display name)
- Required field (no empty values)
**Scale/Scope**: Affects all new user signups and existing user profile updates

## Constitution Check
*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Resource-First Development**:
- [x] All features start with Ash resource definitions
- [x] Resource structure defined before implementation (User resource exists, needs attribute constraint updates)

**Test-After-Resource Pattern**:
- [x] Tests planned for all resource actions (update_display_name action exists, tests need updates)
- [x] Permission matrix tests included (existing permissions cover this)

**Comprehensive Permissions**:
- [x] Permissions matrix documented for all actions (users can update their own display_name)
- [x] Edge cases identified for testing (validation scenarios documented in spec)

**Multi-Endpoint Planning**:
- [x] JSON API endpoints considered (AshJsonApi if needed for mobile/API clients)
- [x] GraphQL endpoints considered (AshGraphql if needed)
- [x] MCP tool endpoints considered (not required for this feature)

**Migration-Driven Evolution**:
- [x] All schema changes via Ash migrations (will generate migration for constraint updates)
- [x] No manual database modifications

**Status**: ✅ PASS - All constitutional requirements met. This feature follows resource-first development by modifying an existing Ash resource.

## Project Structure

### Documentation (this feature)
```
specs/002-signup-display-name/
├── spec.md              # Feature specification (complete)
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
│   └── accounts/
│       ├── user.ex                    # Ash resource (update display_name constraints)
│       └── user/
│           ├── changes/
│           │   └── set_default_display_name.ex  # May need updates
│           └── preparations/
└── huddlz_web/
    ├── live/
    │   └── auth_live/
    │       └── register.ex            # Add display_name field to signup form
    └── components/
        └── core_components.ex         # Use existing input component

test/
├── huddlz/
│   └── accounts/
│       └── user_test.exs              # Update validation tests
└── huddlz_web/
    └── live/
        └── auth_live/
            └── register_test.exs       # Add display_name field tests

priv/
└── repo/
    └── migrations/
        └── [timestamp]_update_user_display_name_constraints.exs  # Generated by Ash
```

**Structure Decision**: Phoenix web application with standard lib/ structure. The Accounts domain contains the User resource managed by Ash. LiveView components in huddlz_web handle the UI layer. This follows the existing codebase pattern.

## Phase 0: Outline & Research

### Technical Context Analysis
All technical context is clear - no NEEDS CLARIFICATION markers. The codebase already uses:
- Ash 3.x with AshPostgres data layer
- Phoenix LiveView for UI
- AshAuthentication for signup flows
- Standard Elixir/Phoenix testing tools

### Research Tasks

1. **Current User Resource Structure**
   - **Decision**: User resource exists in `lib/huddlz/accounts/user.ex`
   - **Current State**:
     - `display_name` attribute exists with constraints: `min_length: 1, max_length: 30, allow_nil?: true`
     - `update_display_name` action exists with validation
     - `SetDefaultDisplayName` change exists
   - **Required Changes**:
     - Update max_length from 30 to 70 characters
     - Change allow_nil? from true to false (required field)
     - Keep all printable characters support (already supported)
   - **Rationale**: Spec requires 70 character max and required field, current implementation is 30 char max and optional

2. **Signup Form Current State**
   - **Decision**: Register LiveView exists at `lib/huddlz_web/live/auth_live/register.ex`
   - **Current State**:
     - Uses `register_with_password` action from AshAuthentication
     - Form includes email and password fields only
     - No display_name field present
   - **Required Changes**:
     - Add display_name input field with placeholder "First and Last Name"
     - Add field to form validation and submission
   - **Rationale**: Spec requires display_name field on signup form with guidance text

3. **Ash Migration Best Practices**
   - **Decision**: Use `mix ash.codegen` to generate migrations automatically
   - **Process**:
     1. Modify User resource attributes
     2. Run `mix ash.codegen update_user_display_name_constraints`
     3. Review generated migration
     4. Run `mix ash.migrate`
   - **Rationale**: Constitutional requirement - all schema changes via Ash migrations

4. **Display Name Validation Patterns**
   - **Decision**: Use Ash built-in validations
   - **Validations Needed**:
     - `string_length(:display_name, min: 1, max: 70)` - enforces length
     - `attribute_does_not_equal(:display_name, "")` - no empty strings
     - No character restrictions (all printable characters including emojis allowed)
   - **Rationale**: Ash provides declarative validation that works consistently across all actions

5. **Testing Strategy**
   - **Decision**: Update existing User tests, add Register LiveView tests
   - **Test Coverage**:
     - Resource action tests: validate constraint changes work
     - Permission tests: ensure users can update own display_name
     - LiveView tests: validate form includes display_name and submits correctly
     - Integration tests: full signup flow with display_name
   - **Rationale**: Constitutional requirement for comprehensive action and permission testing

**Output**: All research complete, no blocking unknowns

## Phase 1: Design & Contracts

### Data Model

**Entity**: User (existing Ash resource - `Huddlz.Accounts.User`)

**Modified Attribute**:
- `display_name` (String)
  - Description: Name the user wants others to identify them as
  - Required: Yes (changed from optional)
  - Constraints:
    - Min length: 1 character
    - Max length: 70 characters (changed from 30)
    - Character set: All printable characters including emojis and special symbols
  - Uniqueness: Non-unique (multiple users can share same display name)
  - Visibility: Public attribute, shown everywhere user is referenced
  - Editability: Can be updated by user anytime via `update_display_name` action

**Existing Action Updates**:
- `create` action: Already accepts display_name, no changes needed
- `register_with_password` action (from AshAuthentication): Needs to accept display_name parameter
- `update_display_name` action: Update validation from max 30 to max 70 characters

**No new relationships or state transitions required**

### API Contracts

**Modified Action: register_with_password** (AshAuthentication strategy action)

```elixir
# Request (LiveView form submission)
%{
  "user" => %{
    "email" => "user@example.com",
    "password" => "securepassword123",
    "password_confirmation" => "securepassword123",
    "display_name" => "John Doe"  # NEW FIELD
  }
}

# Success Response
{:ok, %User{
  id: "uuid",
  email: "user@example.com",
  display_name: "John Doe",
  confirmed_at: nil,  # pending confirmation
  ...
}}

# Validation Errors
{:error, %Ash.Error.Invalid{
  errors: [
    %Ash.Error.Changes.InvalidAttribute{
      field: :display_name,
      message: "must be present"  # if empty
    },
    %Ash.Error.Changes.InvalidAttribute{
      field: :display_name,
      message: "length must be less than or equal to 70"  # if too long
    }
  ]
}}
```

**Modified Action: update_display_name**

```elixir
# Request
%{
  "display_name" => "Jane Smith"
}

# Success Response
{:ok, %User{
  id: "uuid",
  display_name: "Jane Smith",
  ...
}}

# Validation Errors (same as above)
```

### Test Scenarios (from spec)

1. **Scenario: Display name field present on signup**
   - Given: User visits signup page
   - When: Page loads
   - Then: Display name input field visible with placeholder "First and Last Name"

2. **Scenario: Valid display name accepted**
   - Given: User on signup page
   - When: User enters valid display name (1-70 chars) and submits
   - Then: Account created with display name saved

3. **Scenario: Empty display name rejected**
   - Given: User on signup page
   - When: User leaves display name empty and submits
   - Then: Validation error shown, account not created

4. **Scenario: Display name over 70 characters rejected**
   - Given: User on signup page
   - When: User enters display name with 71+ characters and submits
   - Then: Validation error shown, account not created

5. **Scenario: Single-name display name accepted**
   - Given: User on signup page
   - When: User enters single name (e.g., "Madonna") and submits
   - Then: Account created successfully

6. **Scenario: Special characters and emojis accepted**
   - Given: User on signup page
   - When: User enters display name with emojis/special chars (e.g., "José 🎉") and submits
   - Then: Account created successfully

7. **Scenario: Display name shown throughout platform**
   - Given: User has signed up with display name
   - When: Display name is referenced in any context (profile, huddl listings, comments, etc.)
   - Then: Display name is consistently shown

8. **Scenario: User can edit display name**
   - Given: Authenticated user
   - When: User updates display name in profile settings
   - Then: Display name updated with same validation rules applied

### Quickstart Test Outline

See `quickstart.md` for detailed manual testing steps covering:
1. New user signup with display name
2. Display name validation testing
3. Display name visibility across platform
4. Display name editing functionality

**Output**: data-model.md, /contracts/, quickstart.md, CLAUDE.md updated

## Phase 2: Task Planning Approach
*This section describes what the /tasks command will do - DO NOT execute during /plan*

**Task Generation Strategy**:
1. Load resource modification tasks from data-model.md
2. Generate migration tasks (Ash-driven)
3. Extract test tasks from contract specifications
4. Generate UI implementation tasks from user stories
5. Add integration test tasks for end-to-end flows

**Task Categories**:
- **Resource Updates** [P]:
  - Update User resource display_name constraints
  - Update User resource actions to handle display_name
  - Update SetDefaultDisplayName change if needed

- **Database Migrations** (sequential):
  - Generate Ash migration for display_name constraints
  - Review and run migration

- **Testing** [P] (after resource updates):
  - Update User resource action tests
  - Update display_name validation tests
  - Update permission tests for update_display_name
  - Add Register LiveView display_name field tests
  - Add integration tests for full signup flow

- **UI Implementation** [P] (after tests):
  - Update Register LiveView to include display_name field
  - Add display_name to register form
  - Add placeholder text and validation feedback

- **Verification** (sequential, last):
  - Run full test suite
  - Execute quickstart.md manual tests
  - Verify display_name shown across all contexts

**Ordering Strategy**:
- Constitutional order: Resource → Migration → Tests → Implementation
- [P] marks parallelizable tasks (independent files)
- Sequential tasks in dependency order
- All tests written before implementation changes

**Estimated Output**: 12-15 numbered, ordered tasks in tasks.md

**IMPORTANT**: This phase is executed by the /tasks command, NOT by /plan

## Phase 3+: Future Implementation
*These phases are beyond the scope of the /plan command*

**Phase 3**: Task execution (/tasks command creates tasks.md)
**Phase 4**: Implementation (execute tasks.md following constitutional principles)
**Phase 5**: Validation (run tests, execute quickstart.md, verify display_name visibility)

## Complexity Tracking
*No constitutional violations - this section intentionally empty*

This feature strictly follows all constitutional principles:
- Resource-first: Modifying existing Ash User resource
- Test-after-resource: Tests updated after resource changes
- Permissions matrix: Using existing user-owned update permissions
- Migration-driven: All DB changes via Ash migrations
- Multi-endpoint: Standard Ash actions work across all endpoint types

## Progress Tracking
*This checklist is updated during execution flow*

**Phase Status**:
- [x] Phase 0: Research complete (/plan command)
- [x] Phase 1: Design complete (/plan command)
- [x] Phase 2: Task planning approach described (/plan command)
- [ ] Phase 3: Tasks generated (/tasks command)
- [ ] Phase 4: Implementation complete
- [ ] Phase 5: Validation passed

**Gate Status**:
- [x] Initial Constitution Check: PASS
- [x] Post-Design Constitution Check: PASS
- [x] All NEEDS CLARIFICATION resolved
- [x] Complexity deviations documented (none)

---
*Based on Constitution v1.0.0 - See `/.specify/memory/constitution.md`*
