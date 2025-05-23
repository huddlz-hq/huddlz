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

### Testing Ash Resources

- **CiString Attributes**: Always use `to_string()` when comparing CiString fields in assertions
  ```elixir
  assert to_string(group.name) == "Expected Name"
  ```
- **Authorization**: Use `authorize?: false` when testing data access patterns
  ```elixir
  Group |> Ash.Query.filter(owner_id: user.id) |> Ash.read!(authorize?: false)
  ```
- **Query Macros**: Must `require Ash.Query` before using query macros
- **Error Assertions**: Ash errors have specific structure - don't expect a simple `.message` field
  ```elixir
  # Wrong
  assert error.message =~ "is required"
  
  # Right
  assert error.field == :name
  ```

### Testing LiveView Components

- **Layout Consistency**: All LiveView modules should wrap content in `Layouts.app`
- **Authentication**: Navigation tests may redirect to `/sign-in` if authentication is required
- **Form Testing**: Use proper form selectors and handle validation errors appropriately

### Cucumber Testing

- **Database Isolation**: Tests using ConnCase or DataCase properly handle database isolation even with `async: true`
- **User Persistence**: Ensure users are properly created and persisted before authentication steps
- **Step Definitions**: Keep step definitions focused and reusable across scenarios

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