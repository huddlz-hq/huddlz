# Test-First Development with Cucumber

> **See Also**: For Ash Framework-specific testing patterns, see [docs/ash_framework/testing.md](ash_framework/testing.md)

We practice test-first development by starting with a feature description before writing any implementation code. Features are described in plain language using Gherkin syntax, making them easy to understand and review.

## Example Workflow

1. **Write a Feature File**

Create a file in `test/features/` (e.g., `calculator.feature`):

```gherkin
Feature: Calculator
  Scenario: Adding two numbers
    Given I have entered 5 into the calculator
    And I have entered 7 into the calculator
    When I press add
    Then the result should be 12
```

2. **Write a Test Module**

Create a test file in `test/lib/` (e.g., `calculator_test.exs`):

```elixir
defmodule CalculatorTest do
  use Cucumber, feature: "calculator.feature"

  defstep "I have entered {int} into the calculator", context do
    number = List.first(context.args)
    numbers = Map.get(context, :numbers, [])
    {:ok, %{numbers: numbers ++ [number]}}
  end

  defstep "I press add", context do
    result = Enum.sum(context.numbers)
    {:ok, %{result: result}}
  end

  defstep "the result should be {int}", context do
    expected = List.first(context.args)
    assert context.result == expected
    :ok
  end
end
```

## Writing Effective Feature Files

Feature files are the single source of truth for new functionality. Each feature file should:

- Be saved in `test/features/` as `{feature_name}.feature`.
- Use clear Gherkin syntax (`Feature`, `Scenario`, `Given`, `When`, `Then`).
- Cover all relevant scenarios, including both success and error cases.
- Describe what the user will experience in each scenario, including edge cases and validation errors.
- Be updated as understanding evolves—feature files are living documents.

### Example Feature File

```gherkin
Feature: User Login

  Scenario: Successful login
    Given the user is on the login page
    When the user enters valid credentials
    Then the user is redirected to the dashboard

  Scenario: Login with invalid password
    Given the user is on the login page
    When the user enters an incorrect password
    Then an error message is displayed

  Scenario: Login with missing fields
    Given the user is on the login page
    When the user submits the form without entering credentials
    Then a validation error is shown
```

## Checklist for Feature Files

- [ ] All user interactions are described
- [ ] Both success and error scenarios are included
- [ ] Edge cases and validation are covered
- [ ] User experience is clear in each scenario
- [ ] Gherkin syntax is used consistently

3. **Run the Tests**

Run your tests as usual:

```
mix test
```

This approach ensures that every feature starts with a clear specification and is always covered by automated tests.

## Test Support Guidelines

### Test Fixtures

Create reusable test fixtures to set up test data consistently across test scenarios:

1. Place fixtures in `test/support/` directory
2. Create specific fixture modules for each domain concept (e.g., `SoireeFixture`)
3. Design fixtures to be idempotent (can be run multiple times without side effects)
4. Make fixtures flexible with optional parameters for different test needs

Example fixture:
```elixir
defmodule Huddlz.SoireeFixture do
  def create_sample_soirees(count \\ 3) do
    # Create test host with consistent email for lookup
    host = get_or_create_test_host("test.host@example.com")
    
    # Create soirées with sequential information
    for i <- 1..count do
      create_soiree(%{
        title: "Test Soirée #{i}",
        host_id: host.id
      })
    end
  end
end
```

### Test Generators

For more complex data needs, create generators that produce realistic test data:

1. Use the `Ash.Generator` module to create test data generators
2. Place generators in the appropriate domain module: `lib/huddlz/domain/generators/`
3. Use libraries like `Faker` to create diverse, realistic test data
4. Make generators customizable with options to override default values

Example generator:
```elixir
defmodule Huddlz.Soirees.Generators.SoireeGenerator do
  use Ash.Generator
  
  def soiree(opts \\ []) do
    seed_generator(
      %Soiree{
        title: sequence(:title, &"Soirée #{&1}"),
        description: Faker.Lorem.paragraph(),
        starts_at: random_future_date()
      },
      overrides: opts
    )
  end
end
```

### LiveView Testing

When testing LiveView components:

1. Use `Phoenix.LiveViewTest` to interact with LiveView components
2. Test user interactions with `render_click`, `render_submit`, and `render_change`
3. Verify page content using string matching with `=~` operator
4. Structure assertions to verify behavior, not implementation
5. Use background setup steps to establish a known state