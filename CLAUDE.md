# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build/Test Commands

- Setup project: `mix setup`
- Run server: `mix phx.server`
- Run all tests: `mix test`
- Run a single test file: `mix test path/to/test_file.exs`
- Run a specific test: `mix test path/to/test_file.exs:line_number`
- Run Cucumber features: `mix test test/features/`
- Format code: `mix format` (always run before committing changes)
- Run linter: `mix credo --strict` (always run before committing changes)

## Test-Driven Development

This project follows behavior-driven development using Cucumber:
1. Write feature files first in `test/features/` using Gherkin syntax
2. Create step definitions in `test/features/steps/` that test behavior, not implementation
3. Tests should assert what the system does, not how it does it
4. Focus on user-visible outcomes rather than internal implementation details
5. Write the minimal code needed to make tests pass

### Important Testing Guideline

- IMPORTANT: Always implement tests, never skip, comment out, stub, etc... always write good tests they are the backbone of ensuring the code works.

Always test behavior from the user's perspective. Implementation may change, but behavior
tests should remain stable. See docs/testing.md for complete guidelines.

## Code Style Guidelines

- Follow Elixir style conventions with proper spacing and indentation
- Use the pipe operator (`|>`) to chain operations when appropriate
- Modules and functions should have clear, descriptive names in snake_case
- Organize imports: Elixir libraries first, then Phoenix, then project modules
- Write docstrings for public functions with @moduledoc and @doc
- Properly handle errors with pattern matching and descriptive error messages
- Use Phoenix LiveView for interactive UI components
- Implement authentication with AshAuthentication
- Always run `mix format` before committing changes
- **IMPORTANT: Prefer `with` statements over `case` statements for better error handling and readability when handling multiple operations or complex error cases. For single-clause pattern matching, use `case` statements as suggested by Credo**

### Commit Messages

- Follow conventional commits format: `type(scope): concise description`
- Do not include AI attribution lines or AI-generated signatures
- "Co-Authored-By" is reserved for human collaborators only
- Keep first line under 70 characters, no period at the end
- Use imperative, present tense: "add" not "added" or "adds"
- Include a descriptive body with bullet points for specific changes when appropriate
- See `docs/commit-style.md` for complete guidelines

### Naming Conventions

**IMPORTANT: ALWAYS follow these naming conventions precisely**

- A singular event is called a "huddl" (lowercase) - **NEVER** use "event" or any other term
- Multiple events are called "huddlz" (lowercase) - **NEVER** use "events", "huddles", or any other term
- The platform/application name is "huddlz" (lowercase) in all branding, UI copy, and documentation
- In Elixir code, we follow standard conventions:
  - Module names are capitalized (e.g., `Huddlz.Huddls.Huddl`)
  - Variables and function names use snake_case
- When referring to events in comments and documentation, always use lowercase "huddl" and "huddlz"
- This terminology is core to our brand identity and must be maintained consistently

---

### Group Membership Roles & Access Rules

#### Roles

- `owner`: The creator and primary leader of a group. There is only one owner per group, and the owner must be a verified user.
- `organizer`: Trusted, verified users who help manage the group. There can be multiple organizers per group.
- `member`: Regular participants. Members can be either verified or regular (non-verified) users.

#### Verification

- Only verified users can be assigned as `owner` or `organizer`.
- Verified status is required for elevated permissions and visibility.

#### Access Matrix

| User Type/Role         | Group Type | Can See Members? | Notes                  |
|------------------------|------------|------------------|------------------------|
| owner (verified)       | any        | Yes              |                        |
| organizer (verified)   | any        | Yes              |                        |
| member (verified)      | any        | Yes              |                        |
| member (regular)       | any        | No (count only)  |                        |
| non-member (verified)  | public     | Yes              |                        |
| non-member (verified)  | private    | No               |                        |
| non-member (regular)   | any        | No (count only)  |                        |

#### Policy Summary

- Owners and organizers (must be verified) can always see the full member list for their group.
- Verified members can see the full member list for groups they belong to.
- Regular (non-verified) members and non-members can only see the count of members, not the member list.
- Only verified users can be assigned as owner or organizer.
- When creating a group, the owner must be a verified user.

Refer to `docs/group_membership.md` for a detailed rationale and examples.

## Development Tools

### Technology Stack

This project uses:
- Ash Framework for data modeling and business logic
- Ash Authentication for user authentication
- Phoenix for the web interface and LiveView components

### Framework References

#### Ash Framework

For reference on working with Ash Framework, see the detailed documentation in the 
`docs/ash_framework/` directory, covering topics like:

- `docs/ash_framework/relationships.md` - Working with relationships
- `docs/ash_framework/multitenancy.md` - Implementing multi-tenancy
- `docs/ash_framework/authentication.md` - Setting up authentication
- `docs/ash_framework/access_control.md` - Implementing permissions
- `docs/ash_framework/phoenix_integration.md` - Using Ash with Phoenix

Start with `docs/ash_framework/index.md` for a complete overview.

#### Phoenix Framework

For Phoenix-specific questions, refer to:
- [Phoenix documentation](https://hexdocs.pm/phoenix/overview.html)
- [LiveView documentation](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html)

### Tidewave MCP

Always use the Tidewave MCP tools early and often when working with Elixir code:

- `mcp__tidewave__project_eval`: Test and debug Elixir code in the project context
- `mcp__tidewave__get_source_location`: Find where modules and functions are defined
- `mcp__tidewave__execute_sql_query`: Run database queries
- `mcp__tidewave__get_ecto_schemas`: List all available schemas

Using these tools will help you understand code behavior rather than making assumptions.

### Development Patterns

For detailed development patterns and learnings, refer to:

- `docs/development_patterns.md` - Best practices for working with the technology stack
- `docs/development_lifecycle.md` - Complete development workflow from requirements to implementation

These documents contain best practices for:

- Ash Framework authentication flows
- Testing strategies
- Common challenges and solutions
- Feature development workflow
- Knowledge management

## Development Workflow Commands

This project uses custom commands to maintain consistent development practices and knowledge capture. Commands are defined in `.claude/commands/` directory.

### Core Workflow Commands

The development workflow consists of four phases, each with a specific role and objective:

1. **`/plan`** - Requirements Analysis & Task Breakdown
   - **Role**: Project Manager
   - **Objective**: Understand requirements and break down into manageable tasks
   - **Usage**: `/plan description="brief feature description"`
   - **Output**: Creates timestamped task directory with detailed task specifications

2. **`/build`** - Implementation with TDD/BDD
   - **Role**: Expert Engineer
   - **Objective**: Meticulously implement code following test-driven development
   - **Usage**: `/build task_dir="<task_directory_path>"`
   - **Features**: 
     - Automatically resumes in-progress work
     - Enforces quality gates before completion
     - Requires human verification between tasks

3. **`/verify`** - Code Review & Quality Assurance
   - **Role**: Senior Engineer/Reviewer
   - **Objective**: Critical review, testing, and quality validation
   - **Usage**: `/verify task_dir="<task_directory_path>" commit=true|false`
   - **Output**: Comprehensive review results and optional commit

4. **`/reflect`** - Learning Extraction & Process Improvement
   - **Role**: QA Engineer/Process Analyst
   - **Objective**: Identify gaps, extract learnings, improve documentation
   - **Usage**: `/reflect task_dir="<task_directory_path>"`
   - **Updates**: LEARNINGS.md and suggests process improvements

### Quality Gates

**IMPORTANT**: All code must pass quality gates before any commit or completion:

1. **Code Formatting**: `mix format` - Must have zero formatting changes
2. **All Tests Pass**: `mix test` - Must have 100% pass rate, no skipped tests
3. **Static Analysis**: `mix credo --strict` - Must pass with zero issues
4. **Feature Tests**: `mix test test/features/` - All behavior tests must pass

The `/build` command automatically enforces these gates before marking any task as complete.

### Command Usage Examples

```bash
# Start a new feature
/plan description="Add user authentication"

# Build the first task (automatically finds next task)
/build task_dir="20250124_add_user_authentication"

# Or use shortcuts
/build 20250124              # Uses timestamp
/build add_user_authentication # Uses feature name

# Verify completed feature
/verify task_dir="20250124_add_user_authentication" commit=true

# Extract learnings
/reflect task_dir="20250124_add_user_authentication"
```

### Workflow Philosophy

This workflow simulates a team of specialists:
- Each command activates a different cognitive mode
- Tasks are broken into context-window-sized pieces
- Continuous learning improves both AI and process
- Knowledge is captured throughout, not just at the end

For detailed workflow documentation, use the `/workflow` command.

## Knowledge Capture and Session Documentation

Session documentation happens through the workflow commands:

1. **Planning Phase**: Documents requirements analysis and task breakdown
2. **Building Phase**: Captures implementation decisions and challenges
3. **Verification Phase**: Records review findings and fixes
4. **Reflection Phase**: Extracts learnings and updates LEARNINGS.md

For work outside the standard workflow (exploration, documentation, etc.), create session notes manually:
- Create `notes/session-YYYYMMDD-topic.md` at the beginning
- Document decisions, challenges, and outcomes
- Include learnings for future reference

## Custom Commands

When encountering commands with a leading slash (like `/command`):

- Check `.claude/commands/` directory for command definitions
- Commands follow the standard format: `/command param1="value1" param2="value2"`
- If you don't recognize a command, ask for clarification
- Available commands are documented in this section

## Migration Guidelines

- Never edit a migration file, only generate new migrations 
- Because this is an Ash project, generate migrations using: `mix ash.codegen <name_of_change_to_resource>`