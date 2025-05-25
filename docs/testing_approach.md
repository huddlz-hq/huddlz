# Testing Approach

This document describes the hybrid testing approach used in the Huddlz application.

## Overview

We use a hybrid testing approach that leverages the strengths of different testing frameworks:

- **Wallaby** - For Cucumber feature tests (BDD/E2E testing with real browser)
- **PhoenixTest** - For unit and integration tests (fast, no browser needed)
- **ExUnit** - Standard Elixir test framework underlying everything

## Why Hybrid?

During the migration to PhoenixTest (Issue #20), we discovered that PhoenixTest has a critical limitation: it cannot capture flash messages in LiveView after events. This was verified through extensive testing. Since flash messages are a crucial part of our user experience, we needed a solution that could properly test them.

## Framework Responsibilities

### Wallaby (Feature Tests)

Used for all Cucumber step definitions in `test/features/steps/*_steps_test.exs`.

**Strengths:**
- Uses a real browser (Chrome via ChromeDriver)
- Can properly capture flash messages
- Tests actual user experience including JavaScript
- Handles complex interactions like file uploads
- Verifies visual elements are actually visible

**Usage Pattern:**
```elixir
defmodule MyFeatureSteps do
  use Cucumber, feature: "my_feature.feature"
  use HuddlzWeb.WallabyCase

  defstep "I see a flash message", %{session: session} = context do
    assert_has(session, css("[role='alert']", text: "Success!"))
    {:ok, context}
  end
end
```

### PhoenixTest (Unit/Integration Tests)

Used for controller and LiveView tests that don't require full browser capabilities.

**Strengths:**
- Fast execution (no browser overhead)
- Simple API for basic interactions
- Good for testing business logic
- Suitable for API endpoint testing

**Usage Pattern:**
```elixir
defmodule MyLiveViewTest do
  use HuddlzWeb.ConnCase
  import PhoenixTest

  test "renders form", %{conn: conn} do
    conn
    |> visit("/my-page")
    |> assert_has("h1", text: "My Page")
  end
end
```

## Key Differences

### Authentication in Tests

**Wallaby (Feature Tests):**
- Generate magic link tokens directly using `AshAuthentication.Strategy.MagicLink.request_token_for`
- Visit the magic link URL to authenticate
- This avoids process boundary issues with email capture

**PhoenixTest (Unit Tests):**
- Use the `login/2` helper from `HuddlzWeb.ConnCase`
- Directly sets session without going through full auth flow

### Element Selection

**Wallaby:**
- Uses Query helpers: `text_field()`, `button()`, `link()`, `css()`
- More explicit about element types
- Example: `fill_in(session, text_field("Email"), with: "test@example.com")`

**PhoenixTest:**
- Uses string selectors with options
- More flexible matching
- Example: `fill_in(session, "Email", with: "test@example.com")`

### Flash Messages

**Wallaby:**
- ✅ Can see flash messages: `assert_has(session, css("[role='alert']"))`
- Flash messages use `role="alert"` attribute, not `.alert` class

**PhoenixTest:**
- ❌ Cannot capture LiveView flash messages after events
- This is the primary reason for the hybrid approach

## Best Practices

1. **Use Wallaby for Feature Tests** - All Cucumber tests should use Wallaby for comprehensive testing
2. **Use PhoenixTest for Unit Tests** - Fast feedback for isolated component testing
3. **Pattern Match in Steps** - Use `%{session: session, args: args}` in defstep signatures
4. **Direct Token Generation** - For Wallaby auth, generate tokens directly instead of capturing emails
5. **Async Tests** - Enable `async: true` on Wallaby tests for better performance

## Migration Notes

When migrating tests between frameworks:

1. Update the test case module (`WallabyCase` vs `ConnCase`)
2. Update imports (remove `PhoenixTest` for Wallaby)
3. Update element selectors to use appropriate Query helpers
4. Update assertions to use `css()` wrapper for Wallaby
5. Handle authentication appropriately for each framework

## Future Considerations

As PhoenixTest matures, we may be able to consolidate back to a single framework if the flash message limitation is resolved. Until then, this hybrid approach gives us the best of both worlds: comprehensive browser testing where needed and fast unit tests where appropriate.