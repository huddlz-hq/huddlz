# Test-First Development with Cucumber

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

3. **Run the Tests**

Run your tests as usual:

```
mix test
```

This approach ensures that every feature starts with a clear specification and is always covered by automated tests.
