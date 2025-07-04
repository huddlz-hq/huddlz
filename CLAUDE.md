# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build/Test Commands

- Setup project: `mix setup`
- Run server: `mix phx.server`
- Run all tests: `mix test`
- Run a single test file: `mix test path/to/test_file.exs`
- Run a specific test: `mix test path/to/test_file.exs:line_number`
- Run Cucumber features: `mix test test/features/` (runs all compiled feature tests)
  - Note: Cannot run `.feature` files directly with `mix test path/to/file.feature`
  - Feature files are compiled to ExUnit tests at runtime by the Cucumber framework
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

The development workflow combines GitHub Issues for tracking with local files for rich context. This hybrid approach provides the best of both worlds: public visibility and detailed documentation.

1. **`/plan`** - Requirements Analysis & Task Breakdown
   - **Role**: Project Manager
   - **Objective**: Understand requirements and break down into manageable tasks
   - **Usage**: `/plan issue=123`
   - **Output**: Creates local task structure at `tasks/issue-123/` and feature branch
   - **Creates**: index.md (plan), session.md (notes), tasks/ directory, learnings.md

2. **`/build`** - Implementation with TDD/BDD
   - **Role**: Expert Engineer
   - **Objective**: Meticulously implement code following test-driven development
   - **Usage**: `/build issue=123` (auto-detects next task) or `/build issue=123 task=2` (specific task)
   - **Features**:
     - Reads from local task files for requirements
     - Auto-finds next pending task if not specified
     - Updates session.md with real-time progress
     - Captures course corrections with 🔄 emoji
     - Enforces quality gates before completion
     - Requires human verification between tasks

3. **`/sync`** - GitHub Progress Updates
   - **Role**: Communication Bridge
   - **Objective**: Keep GitHub issue updated with local progress
   - **Usage**: `/sync issue=123` or `/sync issue=123 message="Custom update"`
   - **Updates**: Posts progress summary to GitHub issue

4. **`/verify`** - Code Review & Quality Assurance
   - **Role**: Senior Engineer/Reviewer
   - **Objective**: Critical review, testing, and quality validation
   - **Usage**: `/verify issue=123`
   - **Output**: Verification report in session.md, summary to GitHub

5. **`/reflect`** - Learning Extraction & Process Improvement
   - **Role**: QA Engineer/Process Analyst
   - **Objective**: Analyze journey, extract learnings, improve process
   - **Usage**: `/reflect issue=123`
   - **Updates**: Creates local learnings.md, updates global LEARNINGS.md, prepares PR

### Quality Gates

**IMPORTANT**: All code must pass quality gates before any commit or completion:

1. **Code Formatting**: `mix format` - Must have zero formatting changes
2. **All Tests Pass**: `mix test` - Must have 100% pass rate, no skipped tests
3. **Static Analysis**: `mix credo --strict` - Must pass with zero issues
4. **Feature Tests**: `mix test test/features/` - All behavior tests must pass
5. **Visual Verification**: Use Puppeteer to confirm features work in browser
   - Navigate to `http://localhost:4000` (ensure `mix phx.server` is running)
   - Test the implemented feature visually
   - Especially important when tests are failing - verify implementation BEFORE debugging tests
   - Document any UI/UX issues discovered

The `/build` command automatically enforces these gates before marking any task as complete.

### Command Usage Example

```bash
# 1. Start from a GitHub issue
/plan issue=123

# 2. Build tasks in sequence from local files
/build issue=123          # Auto-detects next pending task
/build issue=123 task=2   # Or specify task explicitly

# 3. Sync progress to GitHub periodically
/sync issue=123

# 4. Verify the complete feature
/verify issue=123

# 5. Extract learnings and prepare PR
/reflect issue=123
```

### Local File Structure

After running `/plan issue=123`, you'll have:

```
tasks/issue-123/
├── index.md       # Requirements, plan, and progress tracking
├── session.md     # Real-time implementation notes and learnings
├── tasks/         # Individual task files
│   ├── 01-setup.md
│   ├── 02-models.md
│   └── 03-ui.md
├── learnings.md   # Accumulated insights (created by /reflect)
└── pr-description.md  # PR template (created by /reflect)
```

### Hybrid Workflow Benefits

The workflow combines local files with GitHub integration:

1. **Local Benefits**:
   - Rich context preserved in session notes
   - Fast access without API calls
   - Detailed journey documentation
   - Natural file-based workflows

2. **GitHub Benefits**:
   - Public progress visibility
   - Issue tracking integration
   - Team collaboration
   - Standard PR process

3. **Progress Tracking**:
   - Detailed progress in local session.md
   - Summary updates to GitHub via `/sync`
   - Course corrections marked with 🔄 emoji
   - Continuous learning capture

### Workflow Philosophy

This workflow simulates a team of specialists:
- Each command activates a different cognitive mode
- Tasks are broken into manageable, focused pieces
- Session notes capture the implementation journey
- Learning accumulates throughout, not just at the end
- Hybrid approach balances documentation with visibility

For detailed workflow documentation, use the `/workflow` command.

## Knowledge Capture

Knowledge is captured continuously throughout development via GitHub:

1. **Feature Log**: A pinned comment on parent issues tracks all phases
2. **Progress Updates**: Real-time documentation in sub-issue comments
3. **Course Corrections**: Marked with 🔄 emoji for easy identification
4. **Learnings**: Extracted during reflection and stored in LEARNINGS.md

For exploratory work outside the standard workflow:
- Create `notes/session-YYYYMMDD-topic.md` for documentation
- Capture decisions, experiments, and insights
- Link to relevant issues when applicable

## Custom Commands

When encountering commands with a leading slash (like `/command`):

- Check `.claude/commands/` directory for command definitions
- Commands follow the standard format: `/command param1="value1" param2="value2"`
- If you don't recognize a command, ask for clarification
- Available commands are documented in this section

## Migration Guidelines

- Never edit a migration file, only generate new migrations
- Because this is an Ash project, generate migrations using: `mix ash.codegen <name_of_change_to_resource>`

## Puppeteer Login Instructions

When testing with Puppeteer, use this process for password-based authentication:

```javascript
// 1. Navigate to home and click sign in
await navigate("http://localhost:4000")
await click('a[href="/sign-in"]')

// 2. Fill in the password sign-in form
await fill('input[name="user[email]"]', 'alice@example.com')
await fill('input[name="user[password]"]', 'password123')
// Other test users: bob@example.com, admin@example.com

// 3. Submit the form
await click('button[type="submit"]')

// You are now logged in!
```

**Important Notes:**
- Test users are created by seeds.exs with known passwords
- For password reset testing, use the dev mailbox at `/dev/mailbox`

## Development Mailbox Navigation

The development mailbox at `/dev/mailbox` is still useful for password reset emails:

### HTML View (Recommended - Clickable Links!)

1. **Go to mailbox**: Navigate to `http://localhost:4000/dev/mailbox`
2. **Click on an email**: Click the subject/sender to view email details
3. **Navigate to HTML view**: Add `/html` to the URL
   - Example: `http://localhost:4000/dev/mailbox/[email-id]/html`
4. **Click links directly**: In the HTML view, all links are clickable!

```javascript
// Example: Following a password reset link
await navigate("http://localhost:4000/dev/mailbox")
await click('a[href*="/dev/mailbox/"]')  // Click the email

// Navigate to the HTML view
await navigate("http://localhost:4000/dev/mailbox/[email-id]/html")

// Now you can click the reset link directly!
await click('a[href*="/password-reset/"]')

```
<!-- usage-rules-start -->
<!-- usage-rules-header -->
# Usage Rules

**IMPORTANT**: Consult these usage rules early and often when working with the packages listed below. 
Before attempting to use any of these packages or to discover if you should use them, review their 
usage rules to understand the correct patterns, conventions, and best practices.
<!-- usage-rules-header-end -->

<!-- ash-start -->
## ash usage
_A declarative, extensible framework for building Elixir applications.
_

[ash usage rules](deps/ash/usage-rules.md)
<!-- ash-end -->
<!-- ash_phoenix-start -->
## ash_phoenix usage
_Utilities for integrating Ash and Phoenix
_

[ash_phoenix usage rules](deps/ash_phoenix/usage-rules.md)
<!-- ash_phoenix-end -->
<!-- ash_postgres-start -->
## ash_postgres usage
_The PostgreSQL data layer for Ash Framework
_

[ash_postgres usage rules](deps/ash_postgres/usage-rules.md)
<!-- ash_postgres-end -->
<!-- igniter-start -->
## igniter usage
_A code generation and project patching framework
_

[igniter usage rules](deps/igniter/usage-rules.md)
<!-- igniter-end -->
<!-- elixir-start -->
## elixir usage
_Core Elixir language features and standard library_

# Elixir Core Usage Rules

## Pattern Matching
- Use pattern matching over conditional logic when possible
- Prefer to match on function heads instead of using `if`/`else` or `case` in function bodies

## Error Handling
- Use `{:ok, result}` and `{:error, reason}` tuples for operations that can fail
- Avoid raising exceptions for control flow
- Use `with` for chaining operations that return `{:ok, _}` or `{:error, _}`

## Common Mistakes to Avoid
- Don't use `Enum` functions on large collections when `Stream` is more appropriate
- Avoid nested `case` statements - refactor to a single `case`, `with` or separate functions
- Don't use `String.to_atom/1` on user input (memory leak risk)
- Lists and enumerables cannot be indexed with brackets. Use pattern matching or `Enum` functions.
- Only use macros if explicitly requested

## Function Design
- Use guard clauses: `when is_binary(name) and byte_size(name) > 0`
- Prefer multiple function clauses over complex conditional logic
- Name functions descriptively: `calculate_total_price/2` not `calc/2`

## Data Structures
- Use structs over maps when the shape is known: `defstruct [:name, :age]`
- Prefer keyword lists for options: `[timeout: 5000, retries: 3]`
- Use maps for dynamic key-value data
- Prefer to prepend to lists `[new | list]` not `list ++ [new]`

## Testing
- Run tests in a specific file with `mix test test/my_test.exs` and a specific test 
  with the line number `mix test path/to/test.exs:123`
- Limit the number of failed tests with `mix test --max-failures n`
- Use `@tag` to tag specific tests, and `mix test --only tag` to run only those tests
- Use `assert_raise` for testing expected exceptions: `assert_raise ArgumentError, fn -> invalid_function() end`

<!-- elixir-end -->
<!-- otp-start -->
## otp usage
_OTP (Open Telecom Platform) behaviors and patterns_

# OTP Usage Rules

## GenServer Best Practices
- Keep state simple and serializable
- Handle all expected messages explicitly
- Use `handle_continue/2` for post-init work
- Implement proper cleanup in `terminate/2` when necessary

## Process Communication
- Use `GenServer.call/3` for synchronous requests expecting replies
- Use `GenServer.cast/2` for fire-and-forget messages.
- When in doubt, us `call` over `cast`, to ensure back-pressure
- Set appropriate timeouts for `call/3` operations

## Fault Tolerance
- Set up processes such that they can handle crashing and being restarted by supervisors
- Use `:max_restarts` and `:max_seconds` to prevent restart loops

## Task and Async
- Use `Task.Supervisor` for better fault tolerance
- Handle task failures with `Task.yield/2` or `Task.shutdown/2`
- Set appropriate task timeouts
- Use `Task.async_stream/3` for concurrent enumeration with back-pressure

<!-- otp-end -->
<!-- usage-rules-end -->
