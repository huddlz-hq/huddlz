# Cucumber Shared Steps Documentation

This guide explains the shared steps pattern introduced with the cucumber 0.4.0 upgrade, designed to eliminate code duplication and establish consistent testing patterns across the test suite.

## Overview

Shared steps provide a standardized vocabulary for common testing operations, preventing developers from "thrashing on implementation" when writing tests. Instead of figuring out how to check a flash message or sign in a user each time, developers can use pre-built, tested patterns.

## Benefits of Cucumber 0.4.0

The upgrade from 0.1.0 to 0.4.0 brings several key improvements:
- **Shared step definitions** - Define steps once, use everywhere
- **Better organization** - Steps can be grouped by domain
- **Consistent patterns** - Standard ways to perform common actions
- **PhoenixTest integration** - Works seamlessly with our PhoenixTest migration (Issue #20)

## Shared Step Modules

All shared steps are located in this directory:

### 1. SharedAuthSteps (`shared_auth_steps.exs`)

Handles user creation and authentication operations.

#### Available Steps:

**Creating Users:**
```gherkin
Given the following users exist:
  | email              | display_name | role     |
  | alice@example.com  | Alice Smith  | verified |
  | bob@example.com    | Bob Jones    | regular  |
  | admin@example.com  | Admin User   | admin    |
```
- Creates users with specified attributes
- Roles: `verified`, `regular`, `admin` (defaults to `regular`)
- Automatically handles database sandbox setup

**Authentication:**
```gherkin
Given I am signed in as "alice@example.com"
```
- Signs in the user specified by email
- User must exist (typically created with the step above)
- Sets up proper session and connection context

### 2. SharedUISteps (`shared_ui_steps.exs`)

Handles navigation, clicking, form interactions, and content assertions.

#### Available Steps:

**Navigation:**
```gherkin
Given the user is on the home page
When I visit "/groups"
When the user clicks the "Groups" link in the navbar
```

**Clicking Actions:**
```gherkin
When I click "Sign In"
When I click the "Submit" button
```
- Intelligently tries clicking as both link and button

**Content Assertions:**
```gherkin
Then I should see "Welcome to Huddlz"
Then I should not see "Error"
Then I should see "Success!" in the flash
Then the user should see "Group created"
Then the user should not see "Private content"
```

**Form Interactions:**
```gherkin
When I fill in "Email" with "test@example.com"
When I select "Public" from "Visibility"
```

**Button Visibility:**
```gherkin
Then the "Create Huddl" button should be visible
Then the "Delete" button should not be visible
```

## Usage Examples

### Example 1: User Registration Flow
```gherkin
Feature: User Registration

  Scenario: New user signs up
    Given the user is on the home page
    When I click "Sign Up"
    And I fill in "Email" with "newuser@example.com"
    And I fill in "Display Name" with "New User"
    And I click the "Register" button
    Then I should see "Welcome to Huddlz" in the flash
```

### Example 2: Authenticated User Creating Content
```gherkin
Feature: Create Group

  Background:
    Given the following users exist:
      | email             | display_name | role     |
      | alice@example.com | Alice Smith  | verified |
    And I am signed in as "alice@example.com"

  Scenario: Verified user creates a group
    When I visit "/groups/new"
    And I fill in "Name" with "Book Club"
    And I select "Public" from "Visibility"
    And I click the "Create Group" button
    Then I should see "Group created successfully" in the flash
    And I should see "Book Club"
```

## Adding New Shared Steps

When adding new shared steps, follow these guidelines:

1. **Check if it already exists** - Review existing shared modules first
2. **Choose the right module** - Auth-related goes in SharedAuthSteps, UI/interaction in SharedUISteps
3. **Keep it generic** - Steps should be reusable across different features
4. **Use clear language** - Step definitions should read naturally in English
5. **Handle context properly** - Always check for and preserve session/conn context

### Template for New Steps:
```elixir
step "I do something with {string}", %{args: [value]} = context do
  session = context[:session] || context[:conn]
  
  # Perform action
  session = some_action(session, value)
  
  # Return updated context
  Map.merge(context, %{session: session, conn: session})
end
```

## Migration from Old Patterns

If you're updating tests that use the old patterns:

1. **Replace custom user creation** with `the following users exist:`
2. **Replace custom sign-in logic** with `I am signed in as`
3. **Replace PhoenixTest calls** with shared UI steps where available
4. **Use consistent language** - "I should see" vs "the user should see" (both work)

## Best Practices

1. **Start with shared steps** - Only write custom steps when truly unique
2. **Reuse contexts** - Steps build on each other through context passing
3. **Keep steps focused** - Each step should do one clear thing
4. **Test behavior, not implementation** - Focus on what users see/do
5. **Use descriptive text** - Make scenarios readable by non-developers

## Troubleshooting

**"Step not found" errors:**
- Ensure the shared module is imported in your step file
- Check exact wording matches (case-sensitive)

**Context/session issues:**
- Always preserve session/conn in returned context
- Use `ensure_sandbox()` for database operations

**PhoenixTest conflicts:**
- Shared steps handle PhoenixTest internally
- Don't mix direct PhoenixTest calls with shared steps in same scenario

## Future Enhancements

As patterns emerge, we may add:
- Email/magic link shared steps
- File upload shared steps
- Date/time manipulation steps
- API testing steps

Remember: Let patterns emerge naturally. Don't over-engineer - add shared steps when you find yourself writing the same code multiple times.