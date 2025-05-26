# PhoenixTest Migration Guide

This guide documents the migration from Phoenix.LiveViewTest to PhoenixTest completed in Issue #20.

## Overview

PhoenixTest provides a unified API for testing both LiveViews and regular controller views, eliminating the API inconsistencies between different test types.

## Migration Patterns

### Basic LiveView Test Migration

**Before (Phoenix.LiveViewTest):**
```elixir
{:ok, view, html} = live(conn, "/groups")
assert html =~ "Groups"
html = render(view)
assert html =~ "Welcome"
```

**After (PhoenixTest):**
```elixir
session = conn |> visit("/groups")
assert_has(session, "h1", text: "Groups")
assert_has(session, "p", text: "Welcome")
```

### Form Interactions

**Before:**
```elixir
{:ok, view, _html} = live(conn, "/groups/new")

html = 
  view
  |> element("form")
  |> render_submit(%{
    "group" => %{
      "name" => "Book Club",
      "description" => "Monthly meetings"
    }
  })

assert html =~ "Group created"
```

**After:**
```elixir
session = conn
|> visit("/groups/new")
|> fill_in("Name", with: "Book Club")
|> fill_in("Description", with: "Monthly meetings")
|> click_button("Create Group")

assert_has(session, ".alert", text: "Group created")
```

### Dynamic UI Updates

**Before:**
```elixir
{:ok, view, _html} = live(conn, "/huddls/new")

# Change event type
html = 
  view
  |> element("form")
  |> render_change(%{"huddl" => %{"type" => "virtual"}})

assert html =~ "Virtual Meeting Link"
refute html =~ "Physical Location"
```

**After:**
```elixir
session = conn
|> visit("/huddls/new")
|> select("Event Type", option: "Virtual")

assert_has(session, "label", text: "Virtual Meeting Link")
refute_has(session, "label", text: "Physical Location")
```

### Element Interactions

**Before:**
```elixir
view
|> element("button", "Cancel RSVP")
|> render_click()

html = render(view)
assert html =~ "RSVP cancelled"
```

**After:**
```elixir
session = session
|> click_button("Cancel RSVP")

assert_has(session, ".alert", text: "RSVP cancelled")
```

## Key Differences

### 1. No More Tuples

PhoenixTest returns a session struct instead of `{:ok, view, html}` tuples:
- Simpler pattern matching
- Pipe-friendly operations
- No need to manage view and HTML separately

### 2. Label-Based Form Interactions

PhoenixTest requires proper labels:
```html
<!-- Required for fill_in to work -->
<label for="email">Email</label>
<input id="email" name="user[email]" />

<!-- For hidden labels -->
<label for="search" class="sr-only">Search</label>
<input id="search" name="q" placeholder="Search..." />
```

### 3. Cleaner Assertions

Instead of string matching with `=~`, use structured assertions:
- `assert_has/2` - Check element exists
- `assert_has/3` - Check element with specific text
- `refute_has/2` and `refute_has/3` - Opposite assertions

### 4. Automatic Redirect Handling

PhoenixTest follows redirects automatically:
```elixir
# Automatically follows redirect after form submission
session
|> click_button("Create")
|> assert_path("/groups/123")
```

## Common Gotchas

### 1. Forms Without Labels

PhoenixTest's `fill_in/3` requires proper labels:
```elixir
# Add labels to your forms
<label for="email">Email</label>
<input id="email" name="user[email]" />

# For visually hidden labels
<label for="search" class="sr-only">Search</label>
<input id="search" name="q" placeholder="Search..." />
```

### 2. Complex Selectors

PhoenixTest uses CSS selectors:
```elixir
# Class selectors
assert_has(session, ".alert.alert-success")

# Attribute selectors  
assert_has(session, "[data-role='admin-panel']")

# Nested selectors
assert_has(session, "nav a", text: "Home")
```

## Migration Checklist

When migrating a test file:

- [ ] Remove `import Phoenix.LiveViewTest`
- [ ] PhoenixTest is already imported via ConnCase
- [ ] Replace `live/2` with `visit/2`
- [ ] Replace `render_*` functions with action functions
- [ ] Replace `element/2` selectors with direct actions
- [ ] Replace `html =~` with `assert_has/refute_has`
- [ ] Add labels to forms if missing
- [ ] Run tests and fix any failures

## Benefits

After migration:
- Consistent API across all test types
- No more LiveView/controller conditionals
- Cleaner, more readable tests
- Better error messages
- Faster test execution

## Summary

The PhoenixTest migration successfully unified our testing approach across 209 tests:
- 80 LiveView unit tests
- 4 integration tests
- 7 Cucumber step definition files
- All using the same consistent patterns

This provides a solid foundation for maintaining and extending our test suite.