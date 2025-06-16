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

## Tidewave MCP Server Notes

- If the tidewave mcp server is running without error than `mix phx.server` is running and you don't need to run it

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

[... rest of the existing content remains unchanged ...]