# Cucumber Testing Framework for Elixir

This document describes how to use our Cucumber-inspired Gherkin testing framework for Elixir.

## Overview

The Cucumber framework allows you to write tests in a natural language format using Gherkin syntax. This approach bridges the gap between technical and non-technical stakeholders by enabling:

- Behavior-driven development (BDD)
- Clear documentation of application behavior
- Tests that serve as living documentation

## Quick Start

### 1. Create a Feature File

Feature files use the Gherkin syntax and should be placed in `test/features/` with a `.feature` extension.

```gherkin
# test/features/user_authentication.feature
Feature: User Authentication

Background:
  Given the application is running

Scenario: User signs in with valid credentials
  Given I am on the sign in page
  When I enter "user@example.com" as my email
  And I enter "password123" as my password
  And I click the "Sign In" button
  Then I should be redirected to the dashboard
  And I should see "Welcome back" message
```

### 2. Create a Test Module

Create a test module that uses the `Cucumber` macro:

```elixir
defmodule UserAuthenticationTest do
  use Cucumber, feature: "user_authentication.feature"
  
  # Step definitions
  defstep "the application is running" do
    # Setup code here
    :ok
  end
  
  defstep "I am on the sign in page", context do
    # Navigate to sign in page
    Map.put(context, :current_page, :sign_in)
  end
  
  defstep "I enter {string} as my email", context do
    email = List.first(context.args)
    # Code to enter email
    Map.put(context, :email, email)
  end

  defstep "I enter {string} as my password", context do
    password = List.first(context.args)
    # Code to enter password
    Map.put(context, :password, password)
  end
  
  defstep "I click the {string} button", context do
    button_text = List.first(context.args)
    # Code to click button
    {:ok, %{clicked: button_text}}
  end
  
  defstep "I should be redirected to the dashboard", context do
    # Assertions for redirection
    assert context.current_page == :dashboard
    :ok
  end
  
  defstep "I should see {string} message", context do
    message = List.first(context.args)
    # Assertion for message
    assert_text(message)
    :ok
  end
end
```

### 3. Run Your Tests

Run your tests using the standard mix test command:

```
mix test test/lib/user_authentication_test.exs
```

## Feature Files

Feature files consist of several components:

### Feature

Every feature file starts with the `Feature:` keyword followed by a name and optional description:

```gherkin
Feature: Shopping Cart
  As a user
  I want to add items to my cart
  So that I can purchase them later
```

### Background

The `Background:` section contains steps that are executed before each scenario:

```gherkin
Background:
  Given I am logged in as a customer
  And the product catalog is available
```

### Scenarios

Scenarios are concrete examples of how the feature should behave:

```gherkin
Scenario: Adding an item to an empty cart
  Given I am on the product page for "Ergonomic Keyboard"
  When I click "Add to Cart"
  Then I should see "Item added to cart" message
  And my cart should contain 1 item
```

### Steps

Steps use keywords like `Given`, `When`, `Then`, `And`, and `But`:

- `Given`: Establishes preconditions
- `When`: Describes actions
- `Then`: Specifies expected outcomes
- `And`/`But`: Continues the previous step type

## Step Definitions

Step definitions connect Gherkin steps to actual Elixir code:

### Basic Step Definition

```elixir
defstep "I am logged in as a customer", context do
  # Authentication logic here
  {:ok, %{user: create_and_login_customer()}}
end
```

### Steps with Parameters

Cucumber supports several parameter types:

#### String Parameters

```elixir
defstep "I am on the product page for {string}", context do
  product_name = List.first(context.args)
  # Navigate to product page
  {:ok, %{current_page: :product, product_name: product_name}}
end
```

#### Integer Parameters

```elixir
defstep "I should have {int} items in my wishlist", context do
  expected_count = List.first(context.args)
  # Assertion for wishlist count
  assert get_wishlist_count() == expected_count
  :ok
end
```

#### Data Tables

```gherkin
Scenario: Adding multiple items to cart
  Given I have the following items in my cart:
    | Product Name    | Quantity | Price |
    | Smartphone      | 1        | 699.99|
    | Protection Plan | 1        | 79.99 |
  When I proceed to checkout
  Then the total should be 779.98
```

In your test module:

```elixir
defstep "I have the following items in my cart:", context do
  # Access the datatable
  datatable = context.datatable

  # Access headers
  headers = datatable.headers  # ["Product Name", "Quantity", "Price"]
  
  # Access rows as maps
  items = datatable.maps
  # [
  #   %{"Product Name" => "Smartphone", "Quantity" => "1", "Price" => "699.99"},
  #   %{"Product Name" => "Protection Plan", "Quantity" => "1", "Price" => "79.99"}
  # ]
  
  # Process the items
  {:ok, %{cart_items: items}}
end
```

#### Doc Strings

```gherkin
Scenario: Submit feedback
  When I submit the following feedback:
    """
    I really like your product, but I think
    it could be improved by adding more features.
    Keep up the good work!
    """
  Then my feedback should be recorded
```

In your test module:

```elixir
defstep "I submit the following feedback:", context do
  feedback_text = context.docstring
  # Submit feedback logic
  {:ok, %{submitted_feedback: feedback_text}}
end
```

## Return Values

Step definitions can return values in several ways:

### 1. Return `:ok`

For steps that perform actions but don't need to update context:

```elixir
defstep "I click the submit button", _context do
  # Click logic
  :ok
end
```

### 2. Return a Map

To directly replace the context:

```elixir
defstep "I am on the home page", _context do
  %{current_page: :home}
end
```

### 3. Return `{:ok, map}`

To merge new values into the context:

```elixir
defstep "I search for {string}", context do
  search_term = List.first(context.args)
  # Search logic
  {:ok, %{search_term: search_term, search_results: perform_search(search_term)}}
end
```

### 4. Return `{:error, reason}`

To indicate a step failure with a reason:

```elixir
defstep "the payment should be successful", context do
  if context.payment_status == :success do
    :ok
  else
    {:error, "Expected payment to succeed, but got status: #{context.payment_status}"}
  end
end
```

## Error Handling

The framework provides detailed error reporting to help debug test failures:

### Missing Step Definition

When a step in your feature file has no matching definition:

```
** (Cucumber.StepError) No matching step definition found for step:

  When I try to use a step with no definition

in scenario "Missing Step Example" (test/features/example.feature:6)

Please define this step with:

defstep "I try to use a step with no definition", context do
  # Your step implementation here
  context
end
```

### Failed Step

When a step fails during execution:

```
** (Cucumber.StepError) Step failed:

  Then the validation should succeed

in scenario "Form Submission" (test/features/forms.feature:12)
matching pattern: "the validation should succeed"

Validation failed: invalid input data

Step execution history:
  [passed] Given a form to fill out
  [passed] When I submit invalid data
  [failed] Then the validation should succeed
```

## Best Practices

1. **Keep steps reusable**: Write generic steps that can be used across features
2. **Be explicit**: Write steps that clearly describe the behavior
3. **Use Background for common setup**: Avoid repetition in scenarios
4. **Maintain state in context**: Pass necessary data between steps via the context map
5. **Write clear error messages**: Make debugging easier with descriptive errors
6. **Test one behavior per scenario**: Each scenario should focus on one specific behavior
7. **Use Gherkin as documentation**: Write scenarios that can be understood by non-technical stakeholders

## Examples

### Example 1: User Registration

```gherkin
# test/features/user_registration.feature
Feature: User Registration

Scenario: Successful registration with valid data
  Given I am on the registration page
  When I enter "Jane Doe" as my name
  And I enter "jane@example.com" as my email
  And I enter "SecureP@ss123" as my password
  And I enter "SecureP@ss123" as my password confirmation
  And I click "Register" button
  Then my account should be created
  And I should receive a welcome email
  And I should be redirected to the dashboard
```

```elixir
defmodule UserRegistrationTest do
  use Cucumber, feature: "user_registration.feature"
  
  defstep "I am on the registration page", _context do
    # Navigation logic
    %{current_page: :registration}
  end
  
  defstep "I enter {string} as my name", context do
    name = List.first(context.args)
    # Enter name logic
    {:ok, %{name: name}}
  end
  
  defstep "I enter {string} as my email", context do
    email = List.first(context.args)
    # Enter email logic
    {:ok, %{email: email}}
  end
  
  defstep "I enter {string} as my password", context do
    password = List.first(context.args)
    # Enter password logic
    {:ok, %{password: password}}
  end
  
  defstep "I enter {string} as my password confirmation", context do
    password_confirmation = List.first(context.args)
    # Enter password confirmation logic
    {:ok, %{password_confirmation: password_confirmation}}
  end
  
  defstep "I click {string} button", context do
    button_text = List.first(context.args)
    # Click logic
    
    # Registration logic
    user = create_user(context.name, context.email, context.password)
    {:ok, %{user: user}}
  end
  
  defstep "my account should be created", context do
    # Assertion for account creation
    assert context.user != nil
    assert context.user.email == context.email
    :ok
  end
  
  defstep "I should receive a welcome email", context do
    # Assertion for email receipt
    assert_email_sent(to: context.email, subject: ~r/welcome/i)
    :ok
  end
  
  defstep "I should be redirected to the dashboard", _context do
    # Assertion for redirection
    assert_current_page(:dashboard)
    :ok
  end
end
```

### Example 2: Shopping Cart

```gherkin
# test/features/shopping_cart.feature
Feature: Shopping Cart

Background:
  Given I am logged in
  And the store has the following products:
    | Name          | Price  | Stock |
    | Coffee Mug    | 12.99  | 10    |
    | T-shirt       | 24.99  | 5     |
    | Notebook      | 9.99   | 8     |

Scenario: Adding products to cart
  When I add "Coffee Mug" to my cart with quantity 2
  And I add "T-shirt" to my cart with quantity 1
  Then my cart should contain 3 items
  And the total price should be 50.97
```

```elixir
defmodule ShoppingCartTest do
  use Cucumber, feature: "shopping_cart.feature"
  
  defstep "I am logged in", _context do
    # Login logic
    user = login_as_customer()
    %{user: user, cart: []}
  end
  
  defstep "the store has the following products:", context do
    products = Enum.map(context.datatable.maps, fn product ->
      %{
        name: product["Name"],
        price: String.to_float(product["Price"]),
        stock: String.to_integer(product["Stock"])
      }
    end)
    
    # Setup product catalog
    setup_products(products)
    
    {:ok, %{products: products}}
  end
  
  defstep "I add {string} to my cart with quantity {int}", context do
    product_name = Enum.at(context.args, 0)
    quantity = Enum.at(context.args, 1)
    
    product = Enum.find(context.products, &(&1.name == product_name))
    cart_item = %{product: product, quantity: quantity}
    
    updated_cart = context.cart ++ [cart_item]
    
    {:ok, %{cart: updated_cart}}
  end
  
  defstep "my cart should contain {int} items", context do
    expected_count = List.first(context.args)
    actual_count = Enum.reduce(context.cart, 0, fn item, acc -> acc + item.quantity end)
    
    assert actual_count == expected_count
    :ok
  end
  
  defstep "the total price should be {float}", context do
    expected_total = List.first(context.args)
    
    actual_total = Enum.reduce(context.cart, 0.0, fn item, acc -> 
      acc + (item.product.price * item.quantity)
    end)
    
    assert_in_delta actual_total, expected_total, 0.01
    :ok
  end
end
```

## Architecture

This section explains how our Cucumber implementation works under the hood, providing insights for contributors and advanced users.

### Overview

The Cucumber framework consists of several key components:

1. **Gherkin Parser**: Parses feature files into a structured format
2. **Cucumber Module**: Provides macros and functions for test execution
3. **Step Registry**: Stores and manages step definitions
4. **Error Handling**: Provides detailed error reporting

### Component Interactions

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Feature Files  │────▶│ Gherkin Parser  │────▶│   AST / Model   │
└─────────────────┘     └─────────────────┘     └────────┬────────┘
                                                         │
                                                         ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Test Results   │◀────│ Test Execution  │◀────│  Cucumber DSL   │
└─────────────────┘     └─────────────────┘     └────────┬────────┘
                                                         │
                                                         ▼
                                                ┌─────────────────┐
                                                │  Step Registry  │
                                                └─────────────────┘
```

### Gherkin Parser (gherkin.ex)

The Gherkin parser transforms feature files into an abstract syntax tree (AST) of features, scenarios, and steps:

```elixir
defmodule Gherkin do
  defmodule Feature do
    defstruct [:name, :description, :background, :scenarios, tags: []]
  end
  
  defmodule Background do
    defstruct [:steps]
  end
  
  defmodule Scenario do
    defstruct [:name, :steps, tags: []]
  end
  
  defmodule Step do
    defstruct [:keyword, :text, :line, :docstring, :datatable]
  end
end
```

The parser uses a line-by-line state machine approach to transform the text into these structures. It tracks:

1. The current feature being parsed
2. The current scenario or background
3. The state of multi-line constructs like doc strings and data tables
4. Line numbers for error reporting

### Cucumber Module (cucumber.ex)

The Cucumber module is the core of the framework. It provides:

1. The `use Cucumber` macro that generates ExUnit test cases
2. The step registry for storing and looking up step definitions 
3. The step execution engine

When you write `use Cucumber, feature: "my_feature.feature"`, the module:

1. Reads and parses the specified feature file
2. Generates an ExUnit test case for each scenario
3. Sets up the test to execute each step in sequence
4. Provides the DSL for defining steps

### Step Registry

The step registry maintains a mapping between step patterns and their implementations:

```elixir
# Internal implementation detail
@step_registry %{
  # Each entry is a tuple of {pattern, function} where:
  # - pattern is a compiled regex or cucumber expression
  # - function is the step implementation function
}
```

When a step needs to be executed, the framework:

1. Takes the step text from the Gherkin AST
2. Searches the step registry for a matching pattern
3. If found, extracts parameters and calls the implementation function
4. If not found, raises a detailed "No matching step definition" error

### Step Execution Flow

When executing steps:

1. Background steps are executed first (if present)
2. Scenario steps are executed in order
3. Each step receives the context from the previous step
4. The context is transformed based on the step's return value
5. Step history is tracked for error reporting

### Error Handling (step_error.ex)

The `Cucumber.StepError` module provides enhanced error reporting:

```elixir
defmodule Cucumber.StepError do
  defexception [:message, :step, :pattern, :feature_file, :scenario_name, :failure_reason, :step_history]
  
  # Creates errors for missing step definitions
  def missing_step_definition(step, feature_file, scenario_name, step_history) do
    # Implementation details
  end
  
  # Creates errors for step failures
  def failed_step(step, pattern, failure_reason, feature_file, scenario_name, step_history) do
    # Implementation details
  end
end
```

This module formats error messages with:
- The exact step that failed
- The location in the feature file
- The step pattern that was matched
- The execution history (which steps passed/failed)
- Detailed error information

### Context Management

The context is a map that flows through all steps in a scenario:

1. Initially populated with ExUnit test context
2. Each step can modify, extend, or replace the context
3. Return values determine how the context is updated:
   - `{:ok, map}` merges the map into the context
   - A map directly replaces the context
   - `:ok` or `nil` preserves the context
   - `{:error, reason}` raises an error

### Parameter Type Handling

Parameters in step patterns are extracted and processed:

1. The pattern is compiled into a regex with capture groups
2. When matched against a step text, capture groups become parameters
3. Parameters are converted based on their type:
   - `{string}` - Remains a string
   - `{int}` - Converted to integer
   - `{float}` - Converted to float
   - Custom types - Processed by registered transformers

### Integration with ExUnit

The framework integrates with ExUnit by:

1. Generating test functions that correspond to scenarios
2. Using ExUnit's assertion functions for step verification
3. Leveraging ExUnit's reporting mechanism
4. Extending error handling with detailed step failure information

This design allows Cucumber tests to run alongside traditional ExUnit tests while providing the readability and structure of Gherkin scenarios.

### Directory Structure

```
lib/
├── cucumber.ex            # Main module with macros and step execution
├── cucumber/
│   └── step_error.ex      # Error handling and reporting
└── gherkin.ex             # Feature file parser and AST structures

test/
├── features/              # Feature files (.feature)
│   └── example.feature
└── lib/                   # Test modules using the framework
    └── example_test.exs
```

### Extension Points

The framework provides several extension points for future enhancements:

1. **Parameter Type Registry**: Add custom parameter types
2. **Hook System**: Add before/after hooks for scenarios
3. **Formatter API**: Create custom formatters for test output
4. **Reporter Interface**: Generate test reports in various formats

## Future Enhancements

The following features are planned for future iterations of the framework. These are documented as Gherkin features that we can implement later:

### 1. Scenario Outlines with Examples

```gherkin
Feature: Scenario Outlines Support

Scenario: Implementing Scenario Outlines
  Given I have a feature file with a scenario outline
  When I parse the scenario outline with examples table
  Then I should generate multiple test cases based on the examples
  And each test should run with its own set of values

Scenario: Running Parameterized Tests
  Given I have defined a scenario outline with examples
  When I run the tests
  Then each example row should run as a separate test
  And test results should be reported individually
```

### 2. Before and After Hooks

```gherkin
Feature: Hooks Support

Scenario: Before Hook Implementation
  Given I have defined a before hook in my test module
  When I run any scenario in that module
  Then the before hook should execute before each scenario
  And the hook's context changes should be available to the scenarios

Scenario: After Hook Implementation
  Given I have defined an after hook in my test module
  When a scenario completes execution
  Then the after hook should execute regardless of the scenario outcome
  And it should have access to the final context of the scenario

Scenario: Tagged Hooks
  Given I have defined hooks with specific tags
  When I run scenarios with matching tags
  Then only the hooks with matching tags should execute
  And scenarios without those tags should not trigger those hooks
```

### 3. Pending Steps Support

```gherkin
Feature: Pending Steps

Scenario: Marking Steps as Pending
  Given I have a step definition marked as pending
  When I run a scenario containing that step
  Then the test should be marked as pending
  And subsequent steps should be skipped
  And a clear message should indicate the pending status

Scenario: Auto-Pending for Undefined Steps
  Given I have a scenario with a step that has no definition
  When I run the scenario with the "auto-pending" option
  Then instead of failing, the step should be marked as pending
  And a stub step definition should be generated
```

### 4. Custom Parameter Types

```gherkin
Feature: Custom Parameter Types

Scenario: Defining Custom Parameter Types
  Given I have defined a custom parameter type "product"
  When I use "{product}" in my step definition
  Then the parameter should be automatically converted to my product type
  And I can access its properties directly

Scenario: Parameter Type Transformations
  Given I have defined a parameter type with a transformation function
  When a step matches with that parameter
  Then the raw string should be transformed by my function
  And the transformed value should be available in the context
```

### 5. HTML Reports

```gherkin
Feature: HTML Test Reports

Scenario: Generating HTML Reports
  Given I have run a suite of cucumber tests
  When I request an HTML report
  Then a report should be generated with test results
  And the report should show feature details and scenario statuses

Scenario: Including Screenshots in Reports
  Given I have configured screenshots for failed steps
  When a step fails during execution
  Then a screenshot should be captured
  And it should be embedded in the HTML report
```

### 6. Parallel Test Execution

```gherkin
Feature: Parallel Test Execution

Scenario: Running Scenarios in Parallel
  Given I have multiple scenarios in different feature files
  When I run tests with the parallel option
  Then scenarios should execute in parallel
  And test execution should complete faster than sequential execution

Scenario: Managing Shared State in Parallel Tests
  Given I have scenarios that need isolated state
  When I run tests in parallel
  Then each scenario should have its own isolated context
  And no interference should occur between parallel scenarios
```

### 7. Step Nesting and Composition

```gherkin
Feature: Step Nesting

Scenario: Composing Steps from Other Steps
  Given I have defined a complex multi-step behavior
  When I implement it as a composed step
  Then I should be able to reuse that step in multiple scenarios
  And the composed step should execute all its sub-steps
```

### 8. Step Argument Transformations

```gherkin
Feature: Advanced Parameter Transformations

Scenario: Table to Struct Transformations
  Given I have defined a transformation for data tables
  When I pass a data table to a step
  Then the table should be transformed into my custom struct
  And I can work with the struct in my step definition
  
Scenario: Date String Parsing
  Given I have defined a date parameter type
  When I use "{date}" in a step like "order placed on {date}"
  Then the string should be parsed into a proper Date struct
  And I should be able to perform date operations on it
```

### 9. Shared Steps Between Modules

```gherkin
Feature: Shared Steps Between Modules

Scenario: Importing Steps from Other Modules
  Given I have a module with common step definitions
  When I import those steps into my test module
  Then I can use the imported steps in my scenarios
  And I don't need to redefine the same steps in multiple files

Scenario: Step Libraries
  Given I have organized my steps into reusable libraries
  When I create a new test module
  Then I should be able to import steps from multiple libraries
  And combine them with my feature-specific steps

Scenario: Namespacing Step Definitions
  Given I have steps with similar patterns from different domains
  When I import them with namespaces
  Then steps with the same pattern won't conflict
  And I can use steps from each namespace as needed
```
````
