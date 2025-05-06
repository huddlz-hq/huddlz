# Project Learnings

This document captures key insights, patterns, and best practices discovered during development. It's organized by category to make information easy to find and apply to future work.

## Architecture Patterns

### Phoenix LiveView
- When building LiveView components, focus on individual purpose and reusability
- Use LiveView hooks sparingly and only when DOM manipulation is necessary
- Prefer server-side state management over client-side state when possible

### Ash Framework
- Use `before_action` hooks in resource actions to customize user attributes during signup
- Use `Ash.Changeset.change_attribute/3` to set attribute values (not `set_attribute`)
- Remember that Ash Framework functions often require context as a second parameter
- Use `authorize?: false` only when absolutely necessary (and document why)
- Keep permission policies simple and use the built-in authorization system

### Authentication
- Use the DSL style for auth_overrides with `override` and `set` blocks
- Don't try to update users after authentication as this conflicts with Ash's permission system
- When writing changesets in `before_action`, always include the context parameter: `fn changeset, _context ->`

## Development Patterns

### Elixir Best Practices
- Use the pipe operator (`|>`) to chain operations for better readability
- Group imports by source: Elixir core modules first, then Phoenix, then project modules
- Leverage pattern matching for cleaner control flow instead of multiple conditionals
- Use module attributes for configuration values that might change

### Testing Strategies
- Start with feature files using Gherkin syntax before writing implementation code
- Focus on testing behavior, not implementation details
- Structure Cucumber steps to be reusable across similar scenarios
- Use generators for creating test data to avoid repetition
- Separate UI testing from business logic testing

### Error Handling
- Use pattern matching on error tuples (`{:error, reason}`) for explicit error handling
- Prefer descriptive error messages that identify both what went wrong and where
- When using Ash, leverage built-in error reporting and validation capabilities
- Log errors at appropriate levels (debug, info, warn, error) based on severity

## UI/UX Patterns

### Component Design
- *Add insights about UI component patterns here*

### Responsive Design
- *Add insights about responsive design approaches here*

### Accessibility
- *Add insights about accessibility patterns here*

## Workflow Improvements

### Development Process
- Streamline development workflows based on feature size and complexity
- For large features, follow the full define → plan → build → verify → reflect workflow
- For smaller tasks, use the quickfix command to maintain documentation without overhead
- Automatically document session activities for continuous knowledge capture
- Structure notes consistently to make information easy to find later

### AI Collaboration
- Start with requirements definition before implementation to ensure alignment
- Break complex tasks into manageable components when working with AI
- Maintain session notes to preserve context between AI interactions
- Use a central knowledge repository (LEARNINGS.md) to build institutional knowledge
- Allow AI to reflect on completed work to extract valuable insights

### Tooling
- Leverage custom commands to standardize development workflows
- Extract learnings from implementation immediately while they're fresh
- Use consistent parameter naming across commands for ease of use
- Create specific commands for different types of work (standard features vs. quick fixes)

## Performance Patterns

### Database Optimization
- *Add insights about database performance here*

### LiveView Optimization
- *Add insights about LiveView performance here*

### Asset Optimization
- *Add insights about asset optimization here*

## Common Challenges

### Known Issues
- When implementing LiveView components, be aware of client-side state reset during navigation
- Ash Framework changesets can be confusing when used with complex nested data structures
- Authentication redirects may behave unexpectedly without proper path configuration

### Workarounds
- For LiveView components that need persistent state across navigations, use localStorage or server-side session
- When Ash Framework validation is too restrictive, consider using a custom validator function
- For complex authorization rules, use function-based policies instead of DSL policies

### External Dependencies
- The Ash Framework documentation can be sparse in certain areas; refer to the GitHub repository for examples
- Phoenix LiveView's JavaScript hooks API changes between minor versions; check version compatibility
- When upgrading dependencies, always review the CHANGELOG for breaking changes

---

## How to Use This Document

1. **Before starting work on a new feature:**
   - Review relevant sections to apply established patterns
   - Check known issues to avoid repeated problems

2. **When completing a feature:**
   - Use the `/reflect` command to extract learnings
   - Add new insights to appropriate categories
   - Keep entries concise and actionable

3. **When encountering a problem:**
   - Check if a solution is documented here
   - After solving a new problem, add the solution

This document evolves over time. The goal is to build a knowledge base that improves future development efficiency and quality.