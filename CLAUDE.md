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
- Use conventional commits for git commits (see docs/commit-style.md)
- Write docstrings for public functions with @moduledoc and @doc
- Properly handle errors with pattern matching and descriptive error messages
- Use Phoenix LiveView for interactive UI components
- Implement authentication with AshAuthentication
- Always run `mix format` before committing changes

The project uses Ash Framework for data modeling, Ash Authentication for user auth, 
and Phoenix for the web interface.