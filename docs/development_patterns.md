# Development Patterns and Learnings

This document captures key development patterns, learnings, and best practices discovered during the implementation of Huddlz.

## Ash Framework Patterns

### Authentication Flows

- **Do**: Use `before_action` hooks in resource actions to customize user attributes during signup
- **Don't**: Try to update users after authentication as this conflicts with Ash's permission system
- **Do**: When writing changesets in `before_action`, always include the context parameter: `fn changeset, _context ->`
- **Do**: Keep permission policies simple and use the built-in authorization system

### Changeset Functions

- **Do**: Use `Ash.Changeset.change_attribute/3` to set attribute values (not `set_attribute`)
- **Do**: Remember that Ash Framework functions often require context as a second parameter
- **Do**: Use `authorize?: false` only when absolutely necessary (and document why)

### Authentication Styling

- **Do**: Use the DSL style for auth_overrides with `override` and `set` blocks:
  ```elixir
  override AshAuthentication.Phoenix.Components.MagicLink do
    set :disable_button_text, "Sending magic link..."
  end
  ```

## Testing Patterns

### Testing Authentication Flows

- **Challenge**: Testing with actual tokens can be complicated in the test environment
- **Solution**: Focus on testing the specific functions that implement the behavior
- **Example**: For display name generation, test the generator function directly
- **Approach**: For complex flows, use separate integration tests for each component
- **Tip**: Mock authentication when needed rather than trying to extract tokens from emails

## Development Tools

### Tidewave MCP Tools

- **When to use**: Whenever working with Elixir/Phoenix to explore code, test functions, or debug issues
- **Key commands**:
  - `project_eval`: Evaluate Elixir code in the context of the project
  - `get_source_location`: Find where functions are defined
  - `execute_sql_query`: Run database queries
  - `get_ecto_schemas`: List available schemas
  - `package_docs_search`: Search documentation

- **Best practice**: Use Tidewave MCP early and often to understand code behavior rather than making assumptions