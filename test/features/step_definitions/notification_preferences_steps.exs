defmodule NotificationPreferencesSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import PhoenixTest

  alias Huddlz.Notifications.Triggers

  step "I turn off {string}", %{args: [label]} = context do
    session = uncheck(session(context), label)
    Map.merge(context, %{session: session, conn: session})
  end

  step "I turn on {string}", %{args: [label]} = context do
    session = check(session(context), label)
    Map.merge(context, %{session: session, conn: session})
  end

  step "the page confirms the change was saved", context do
    assert_has(session(context), "*", text: "Saved", exact: true)
    context
  end

  step "there is no Save button", context do
    refute_has(session(context), "button", text: "Save")
    context
  end

  step "{string} is off", %{args: [label]} = context do
    assert_has(session(context), switch_for(label) <> "[aria-checked=false]")
    context
  end

  step "{string} is on", %{args: [label]} = context do
    assert_has(session(context), switch_for(label) <> "[aria-checked=true]")
    context
  end

  step "the always-sent list names {string}", %{args: [label]} = context do
    assert_has(session(context), "#always-sent li", text: label)
    context
  end

  step "{string} has no switch", %{args: [label]} = context do
    refute_has(session(context), switch_for(label))
    context
  end

  defp session(context), do: context[:session] || context[:conn]

  defp switch_for(label) do
    {trigger, _entry} =
      Enum.find(Triggers.all(), fn {_trigger, entry} -> entry.label == label end) ||
        flunk("no notification trigger labelled #{inspect(label)}")

    "input[role=switch][name='prefs[#{Triggers.preference_key(trigger)}]']"
  end
end
