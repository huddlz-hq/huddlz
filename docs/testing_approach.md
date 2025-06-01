# Testing Approach

This document describes the testing approach used in the Huddlz application.

## Overview

We use a consistent testing approach across the entire test suite:

- **PhoenixTest** - For all LiveView unit tests, integration tests, and Cucumber step definitions
- **ExUnit** - Standard Elixir test framework underlying everything
- **Standard Phoenix testing** - Only for direct render tests (error pages)

## Why PhoenixTest?

PhoenixTest provides a unified API for testing both LiveViews and regular controller views, eliminating the need for conditionals and reducing cognitive overhead. It offers:

- Consistent patterns across all test types
- Simplified form interactions
- Automatic handling of LiveView redirects
- Clean, pipe-friendly API

## Framework Responsibilities

### PhoenixTest (All Tests)

Used for all test types:
- LiveView unit tests in `test/huddlz_web/live/`
- Integration tests in `test/integration/`
- Cucumber step definitions in `test/features/steps/`

**Strengths:**
- Consistent API across all test types
- Fast execution
- Simple, intuitive patterns
- Pipe-friendly operations
- Automatic LiveView redirect handling

**Usage Pattern:**
```elixir
defmodule MyFeatureSteps do
  use Cucumber, feature: "my_feature.feature"
  use HuddlzWeb.ConnCase

  defstep "I see the page title", %{session: session} = context do
    session = assert_has(session, "h1", text: "Welcome")
    {:ok, Map.put(context, :session, session)}
  end
end
```

### Standard Phoenix Testing (Error Pages Only)

Used only for testing error page rendering directly:

```elixir
defmodule HuddlzWeb.ErrorHTMLTest do
  use HuddlzWeb.ConnCase
  import Phoenix.Template

  test "renders 404.html" do
    assert render_to_string(HuddlzWeb.ErrorHTML, "404", "html", []) == "Not Found"
  end
end
```

## Key Patterns

### Authentication in Tests

**PhoenixTest:**
- Use the `login/2` helper from `HuddlzWeb.ConnCase`
- For Cucumber tests, use magic link flow with proper email assertion

### Element Selection

**PhoenixTest uses intuitive patterns:**
- `fill_in("Label", with: "value")` - Fills form fields by label
- `select("Label", option: "Option text")` - Selects dropdown options
- `click_button("Button text")` - Clicks buttons by text
- `assert_has("selector", text: "content")` - Verifies elements exist

### Form Requirements

PhoenixTest requires proper labels with `for` attributes:

```elixir
# Form inputs need labels
<label for="input-id">Field Label</label>
<input id="input-id" name="field_name" />

# For visually hidden labels
<label for="search" class="sr-only">Search</label>
<input id="search" name="q" placeholder="Search..." />
```

### Flash Messages

PhoenixTest handles flash messages seamlessly:

```elixir
# Test flash messages directly
assert_has(session, ".alert", text: "Successfully created")
assert_has(session, "[role='alert']", text: "Error occurred")
```

## Best Practices

1. **Consistent Patterns** - Use PhoenixTest patterns across all test types
2. **Proper Labels** - Ensure all form inputs have labels with `for` attributes
3. **Pattern Match in Steps** - Use `%{session: session} = context` in defstep signatures
4. **Update Session** - Always return updated session in context map
5. **Focus on Behavior** - Test what users see, not implementation details

## Common Patterns

### Basic Test Structure

```elixir
test "user can create a group", %{conn: conn} do
  user = create_verified_user()

  conn
  |> login(user)
  |> visit("/groups/new")
  |> fill_in("Name", with: "Book Club")
  |> fill_in("Description", with: "Monthly book discussions")
  |> click_button("Create Group")
  |> assert_has("h1", text: "Book Club")
end
```

### Cucumber Step Definitions

```elixir
defstep "the user fills in the form", %{session: session} = context do
  session = session
  |> fill_in("Email", with: "test@example.com")
  |> click_button("Submit")

  {:ok, Map.put(context, :session, session)}
end
```

## Summary

PhoenixTest provides a unified testing experience across the Huddlz application:

- **209 tests** successfully migrated and passing
- **Consistent API** for all test types
- **Clean patterns** that are easy to understand and maintain
- **Fast execution** without browser overhead

The only exceptions are error template tests that directly test render functions without HTTP requests.