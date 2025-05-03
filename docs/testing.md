I would like to develop this project using gherkin. There aren't any good tools for gherkin in elixir so let's write a testing tool ourselves. Here is how I envision it working:

1. you make a feature file in the `test/features` folder using the gherkin 6 syntax 
you can read about it here https://cucumber.io/docs/gherkin/reference

```
# test/features/user_joins_event.feature

Feature: User signs up for event

Background:
Given a logged in user

Scenario: User joins an event
Given an event titled "Tech Gathering"
When I visit "/"
Then I should see the event
When I click "join" on the first event
Then I should see "joined event"
```

2. then you just write a regular test file but you use our new cucumber module:
```
defmodule MyFeatureTest do
  use Cucumber, feature: "my_feature.feature"

  defstep "a logged in user" do
    {:ok, %{user: login_user())}
  end

  defstep "I \"{}\" on the first event" do
    event = arg1
    click_on(event)
    :ok
  end
end

  etc...
end
```

3. elixir expands those macros to a normal test file, so you can image that compiling to:
```
defmodule MyFeatureTest do
  use ExUnit.Case

  # features become describes
  describe "User signs up for event" do
    # backgrounds become setup blocks
    setup test_context do
      step(test_context, "a logged in user")
    end

    # scenearios become tests
    test "User joins an event", test_context do
      #given, when, then, etc... become step calls
      step(text_context, "an event titled "Tech Gathering")
      |> step("I visit \"/\"")
      |> step("I should see the event")
      |> step("click \"join\" on the first event")
      |> step("Then I should see \"joined event\"")
    end
  end

  # defstep becomes `steps`
  def step(context, ["a logged in user"]) do
    case {:ok, %{user: login_user())} do
      # allow same arguments as setup from ExUnit
      {:ok, value} -> Enum.into(value, context)
      {:error, error} -> # raise assertion error? what does ExUnit do?
    end
  end

  def step(context, ["I \", arg1, \" on the first event"]) do
    event = arg1
    click_on(event)
    :ok 
  end
end
```