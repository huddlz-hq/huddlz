# Ash Framework: Testing

This document covers best practices and patterns for testing Ash Framework applications, with a focus on authentication, LiveView, and comprehensive test helpers.

## Table of Contents

- [Setting Up the Testing Environment](#setting-up-the-testing-environment)
- [Testing Authentication and Protected Routes](#testing-authentication-and-protected-routes)
- [Creating Reusable Test Helpers](#creating-reusable-test-helpers)
- [Testing LiveView Interactions](#testing-liveview-interactions)
- [Best Practices](#best-practices-for-testing-ash-applications)
- [Key Testing Functions](#key-test-functions-for-ash-applications)

## Setting Up the Testing Environment

### Configuring Ash for Testing

When testing Ash applications, specific configurations are needed for the test environment:

```elixir
# In config/test.exs
config :ash, :disable_async?, true
config :ash, :missed_notifications, :ignore
```

These settings:
1. Disable asynchronous processing to prevent race conditions during tests
2. Ignore Ecto transaction notifications which can cause issues in the test environment

### Adding mix_test_watch for Development

For a streamlined development workflow, the `mix_test_watch` tool can be added:

```bash
# Using Igniter
mix igniter.install mix_test_watch

# Or manually in mix.exs
defp deps do
  [
    {:mix_test_watch, "~> 1.0", only: :dev, runtime: false}
    # other deps...
  ]
end
```

This tool automatically runs tests when files change, providing immediate feedback during development.

## Testing Authentication and Protected Routes

### Testing Guest Access Restrictions

To verify that unauthenticated users cannot access protected routes:

```elixir
defmodule HelpcenterWeb.KnowledgeBase.CategoriesLiveTest do
  use HelpcenterWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  
  test "Guest cannot access /categories", %{conn: conn} do
    assert conn
           |> live(~p"/categories")
           # Guests are redirected to login page
           |> follow_redirect(conn, "/sign-in")
  end
end
```

This test confirms that:
- Unauthenticated users attempting to access protected routes are redirected
- The authentication system is properly integrated with route protection

### Testing Authenticated Access

Testing protected routes requires setting up authenticated sessions:

```elixir
test "User can see a list of categories", %{conn: conn} do
  # Create test user
  user = create_user()
  
  # Add test data
  categories = get_categories()

  # Access protected page with authenticated connection
  {:ok, _view, html} =
    conn
    |> login(user)
    |> live(~p"/categories")

  # Verify content
  assert html =~ "Categories"
  
  # Verify each category is displayed
  for category <- categories do
    assert html =~ category.name
  end
end
```

## Creating Reusable Test Helpers

To avoid repetition and improve test organization, extract common testing logic:

### Authentication Helper

```elixir
# In test/support/auth_case.ex
defmodule AuthCase do
  def login(conn, user) do
    case AshAuthentication.Jwt.token_for_user(user, %{}, domain: Helpcenter.Accounts) do
      {:ok, token, _claims} ->
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      {:error, reason} ->
        raise "Failed to generate token: #{inspect(reason)}"
    end
  end

  def create_user do
    Helpcenter.Accounts.User
    |> Ash.Seed.seed!(%{email: "test@example.com"})
  end
end
```

### Data Generation Helper

```elixir
# In test/support/category_case.ex
defmodule CategoryCase do
  alias Helpcenter.KnowledgeBase.Category

  @doc """
  Get a single category from the database. If none exists,
  insert categories and return the first one.
  """
  def get_category do
    case Ash.read_first(Category) do
      {:ok, nil} -> create_categories() |> Enum.at(0)
      {:ok, category} -> category
    end
  end

  @doc """
  Get a list of categories. If none exist in the database,
  insert them and return the list.
  """
  def get_categories do
    case Ash.read(Category) do
      {:ok, []} -> create_categories()
      {:ok, categories} -> categories
    end
  end

  @doc """
  Insert categories into the database.
  """
  def create_categories do
    attrs = [
      %{
        name: "Account and Login",
        slug: "account-login",
        description: "Help with account creation and login issues"
      },
      # Additional test categories...
    ]

    Ash.Seed.seed!(Category, attrs)
  end
end
```

## Testing LiveView Interactions

Ash applications often use LiveView for interactive interfaces. Testing these interactions requires simulating user actions:

### Testing Form Submissions

```elixir
test "User can edit category from the UI", %{conn: conn} do
  category = get_category()

  # Navigate to edit page
  {:ok, view, html} =
    conn
    |> login(create_user())
    |> live(~p"/categories/#{category.id}")

  # Verify form is rendered
  assert html =~ category.name
  assert html =~ "form[name]"

  # Prepare updated attributes
  attributes = %{
    name: "#{category.name} updated",
    description: "#{category.description} updated."
  }

  # Test form validation
  assert view
         |> form("#category-form-#{category.id}", form: %{name: ""})
         |> render_change() =~ "required"

  # Submit form and follow redirect
  assert view
         |> form("#category-form-#{category.id}", form: attributes)
         |> render_submit()
         |> follow_redirect(conn, "/categories")

  # Verify database was updated
  require Ash.Query
  assert Helpcenter.KnowledgeBase.Category
         |> Ash.Query.filter(name == ^attributes.name)
         |> Ash.exists?()
end
```

### Testing UI Element Interactions

```elixir
test "User can go to the new category form page from the list", %{conn: conn} do
  {:ok, view, _html} =
    conn
    |> login(create_user())
    |> live(~p"/categories")
    
  # Click the create button and follow redirect
  assert view
         |> element("#create-category-button")
         |> render_click()
         |> follow_redirect(conn, ~p"/categories/create")
end
```

### Testing Delete Operations

```elixir
test "User should be able to delete an existing category", %{conn: conn} do
  category = get_category()

  {:ok, view, html} =
    conn
    |> login(create_user())
    |> live(~p"/categories")

  # Verify category exists initially
  assert html =~ category.name

  # Trigger delete action
  view
  |> element("#delete-button-#{category.id}")
  |> render_click()

  # Verify category was removed from database
  require Ash.Query
  refute Helpcenter.KnowledgeBase.Category
         |> Ash.Query.filter(id == ^category.id)
         |> Ash.exists?()
end
```

## Best Practices for Testing Ash Applications

1. **Data Isolation**: Use `Ash.Seed` for test data setup instead of raw database operations
2. **Test for Permissions**: Verify both allowed and disallowed operations for different user types
3. **Helper Modules**: Create helper modules to reduce duplication in tests
4. **Complete Workflows**: Test end-to-end workflows, not just individual operations
5. **Verify Database State**: Check that database records reflect UI operations
6. **LiveView Testing**: Use `render_click`, `render_submit`, and other LiveView test helpers
7. **Authentication Testing**: Test both authenticated and unauthenticated scenarios

## Key Test Functions for Ash Applications

1. **Ash.Seed.seed!/2**: Creates test records with specific attributes
2. **Ash.exists?/1**: Verifies if records matching a query exist
3. **Ash.read/1, Ash.read_first/1**: Retrieves records for verification
4. **Ash.Query.filter/2**: Builds queries to verify database state

## LiveView Testing Functions

1. **live/2**: Connects to a LiveView for testing
2. **element/2**: Selects a DOM element for interaction
3. **render_click/1**: Simulates clicking an element
4. **form/3**: Selects a form for interaction
5. **render_change/1**: Simulates form field changes
6. **render_submit/1**: Simulates form submission
7. **follow_redirect/3**: Follows LiveView redirects