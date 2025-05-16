# Testing Ash Resources

## Best Practices for Testing Ash Resources

Based on the [Ash Framework documentation](https://hexdocs.pm/ash/test-resources.html), here are key considerations for testing resources:

### 1. Test Resource Actions

Always test resource actions to:
- Confirm our understanding of how the application behaves now
- Ensure that our application does not change in unintended ways later

For each action, consider testing:
- Valid input scenarios
- Invalid input scenarios
- Error handling
- Side effects (e.g., notifications, related records)

### 2. Testing Policies and Permissions

Authorization is a critical aspect of Ash resources. Test:

- Different user roles and their permissions
- Who can read/create/update/delete resources
- Edge cases in authorization rules

Example:
```elixir
test "admin users can search other users" do
  admin = generate_admin_user()
  regular_user = generate_regular_user()
  
  # Test from admin perspective
  assert Ash.can?(Huddlz.Accounts.User, :search_by_email, actor: admin)
  
  # Test from regular user perspective  
  refute Ash.can?(Huddlz.Accounts.User, :search_by_email, actor: regular_user)
end
```

### 3. Using Ash.can? in Tests

The `Ash.can?` function is the primary way to test permissions:

```elixir
# Syntax: Ash.can?(resource, action, options)
Ash.can?(User, :search_by_email, actor: admin_user)
```

Key options for `Ash.can?`:
- `actor:` - The user attempting the action
- `data:` - The specific record being acted upon
- `tenant:` - For multi-tenant applications

### 4. Testing LiveView Integrations

For LiveViews that use Ash resources:

1. Test authorization hooks:
```elixir
test "non-admin users cannot access admin panel" do
  conn = 
    conn
    |> login_as(regular_user)
    |> get("/admin")
    
  assert redirected_to(conn) == "/"
end
```

2. Test data operations:
```elixir
test "admin can update user roles" do
  {:ok, view, _} = 
    conn
    |> login_as(admin_user) 
    |> live("/admin")
    
  # Perform role update
  html = view
         |> element("form")
         |> render_submit(%{...})
         
  # Assert changes
  assert html =~ "Role updated successfully"
end
```

### 5. Setup for Testing

In `config/test.exs`, add:

```elixir
config :ash, :disable_async?, true
config :ash, :missed_notifications, :ignore
```

### Resources for Testing

- [Smokestack](https://hexdocs.pm/smokestack) - Test factories for Ash resources
- [PropCheck](https://hexdocs.pm/propcheck) - Property-based testing
- [Ash Testing Documentation](https://hexdocs.pm/ash/testing.html)

## Creating Tests for Our Admin Panel

For our admin panel functionality, we should create these tests:

1. **User Resource Policy Tests**
   - Test that the `search_by_email` action is restricted to admin users
   - Test that the `update_role` action is restricted to admin users

2. **LiveView Access Tests**
   - Test that regular users get redirected from admin panel
   - Test that admin users can access the admin panel

3. **Admin Functionality Tests**
   - Test searching for users by email
   - Test updating user roles

Adding these tests will ensure our admin panel works correctly and future changes don't break its functionality.