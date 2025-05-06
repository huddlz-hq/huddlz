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

## Test-Driven Development

This project follows behavior-driven development using Cucumber:
1. Write feature files first in `test/features/` using Gherkin syntax
2. Create step definitions in `test/features/steps/` that test behavior, not implementation
3. Tests should assert what the system does, not how it does it
4. Focus on user-visible outcomes rather than internal implementation details
5. Write the minimal code needed to make tests pass

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

### Commit Messages

- Follow conventional commits format: `type(scope): concise description`
- Do not include AI attribution lines or AI-generated signatures
- "Co-Authored-By" is reserved for human collaborators only
- Keep first line under 70 characters, no period at the end
- Use imperative, present tense: "add" not "added" or "adds"
- Include a descriptive body with bullet points for specific changes when appropriate
- See `docs/commit-style.md` for complete guidelines

### Naming Conventions

- A singular event is called a "huddl" (lowercase)
- Multiple events are called "huddlz" (lowercase)
- The platform/application name is "huddlz" (lowercase) in all branding, UI copy, and documentation
- In Elixir code, we follow standard conventions:
  - Module names are capitalized (e.g., `Huddlz.Huddls.Huddl`)
  - Variables and function names use snake_case
- When referring to events in comments and documentation, always use lowercase "huddl" and "huddlz"

The project uses Ash Framework for data modeling, Ash Authentication for user auth, 
and Phoenix for the web interface.

## Development Tools

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

## Knowledge Capture and Session Documentation

For all substantial work sessions:

1. **Automatically Create Session Notes**: 
   - Create `notes/session-YYYYMMDD-topic.md` at the beginning of any significant session
   - Use a descriptive topic based on the user's initial request
   - Structure with sections: Goals, Activities, Decisions, Outcomes, Learnings, Next Steps

2. **During the Session**:
   - Update the session notes after each significant step or decision
   - Record all meaningful changes, commands run, and files modified
   - Document rationales for important decisions 
   - Note any challenges encountered and how they were resolved

3. **At Session End**:
   - Add a session summary with key outcomes and learnings
   - Identify any items to be added to `LEARNINGS.md`
   - Suggest improvements to documentation or processes
   - List potential follow-up tasks

This proactive documentation approach applies to all types of work:
- Feature development
- Bug fixes
- Infrastructure improvements
- Workflow refinements
- Exploratory sessions
- Documentation work

## Custom Commands

When encountering commands with a leading slash (like `/command`):

- If you don't recognize a command or are uncertain about its purpose or process, ask for clarification
- Don't assume meaning based on context or guesswork
- Request details about the command's phases or steps if they're referenced
- Only proceed once you have clear instructions about what the command requires
- Avoid implementing partial functionality based on assumptions

Example response for unknown commands:
"I'm not familiar with the `/command` command. Could you please explain what this command should do and what steps or phases it involves?"