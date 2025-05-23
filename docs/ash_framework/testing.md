# Testing Ash Framework Resources

This guide covers best practices and common patterns for testing Ash Framework resources in Elixir applications.

## Key Testing Patterns

### 1. CiString Attribute Handling

Ash's CiString (case-insensitive string) type requires special handling in tests:

```elixir
# ❌ Wrong - Direct comparison will fail
assert group.name == "Test Group"

# ✅ Right - Convert to string first
assert to_string(group.name) == "Test Group"
```

This applies to all CiString fields like name, description, etc.

### 2. Query Authorization

When testing queries, you often need to bypass authorization to test the data layer directly:

```elixir
# ❌ Wrong - May fail due to authorization policies
groups = Group |> Ash.Query.filter(is_public: true) |> Ash.read!()

# ✅ Right - Bypass authorization for testing
groups = Group |> Ash.Query.filter(is_public: true) |> Ash.read!(authorize?: false)
```

Use `authorize?: false` when:
- Testing data access patterns
- Setting up test data
- Verifying query logic independent of permissions

### 3. Query Macro Requirements

Always require Ash.Query before using query macros:

```elixir
defmodule MyTest do
  use MyApp.DataCase
  
  # ✅ Required for using Ash.Query macros
  require Ash.Query
  
  test "filters groups by owner" do
    Group
    |> Ash.Query.filter(owner_id: user.id)
    |> Ash.read!()
  end
end
```

### 4. Error Structure Assertions

Ash errors have a specific structure. Don't expect a simple `.message` field:

```elixir
# ❌ Wrong - Ash errors don't have a direct message field
assert error.message =~ "is required"

# ✅ Right - Check the field that caused the error
assert error.field == :name

# ✅ Right - For validation errors with messages
assert error.message =~ "greater than or equal"

# ✅ Right - Check error type
assert %Ash.Error.Changes.Required{} = error
```

### 5. Testing Changesets and Actions

When testing create/update actions:

```elixir
# Create with changeset
{:ok, group} =
  Group
  |> Ash.Changeset.for_create(:create_group, %{
    name: "Test Group",
    owner_id: owner.id
  })
  |> Ash.create(actor: owner)

# Update with changeset
{:ok, updated} =
  group
  |> Ash.Changeset.for_update(:update_details, %{
    name: "Updated Name"
  })
  |> Ash.update(actor: owner)
```

### 6. Testing with Generators

Use generators to create test data consistently:

```elixir
setup do
  owner = generate(user(role: :verified))
  group = generate(group(
    name: "Test Group",
    owner_id: owner.id,
    actor: owner
  ))
  
  %{owner: owner, group: group}
end
```

## Common Pitfalls

### 1. Forgetting Authorization Context

```elixir
# ❌ May fail if no actor provided
Ash.get!(Group, group_id)

# ✅ Provide actor or disable authorization
Ash.get!(Group, group_id, actor: user)
# or
Ash.get!(Group, group_id, authorize?: false)
```

### 2. Assuming Error Message Format

```elixir
# ❌ Error messages may vary
assert error.message == "is required"

# ✅ More flexible assertion
assert error.field == :name
assert error.__struct__ == Ash.Error.Changes.Required
```

### 3. Testing Implementation Instead of Behavior

```elixir
# ❌ Testing internal changeset details
assert changeset.changes.name == "Test"

# ✅ Testing the outcome
{:ok, group} = Ash.create(changeset)
assert to_string(group.name) == "Test"
```

## Integration with LiveView Tests

When testing LiveView components that use Ash resources:

```elixir
test "displays group details", %{conn: conn, group: group} do
  {:ok, _view, html} = live(conn, ~p"/groups/#{group.id}")
  
  # Remember to convert CiString fields
  assert html =~ to_string(group.name)
  assert html =~ to_string(group.description)
end
```

## Cucumber/BDD Testing

For Cucumber tests with Ash:

1. Tests can run asynchronously when using ConnCase or DataCase - database isolation is handled properly
2. Ensure proper data persistence in setup steps
3. Use `authorize?: false` when looking up test data

## Testing Checklist

- [ ] Add `require Ash.Query` when using query macros
- [ ] Use `to_string()` for CiString comparisons
- [ ] Consider authorization context (`actor` or `authorize?: false`)
- [ ] Test behavior, not implementation
- [ ] Handle error structures appropriately
- [ ] Use generators for consistent test data
- [ ] Use ConnCase or DataCase for proper database isolation