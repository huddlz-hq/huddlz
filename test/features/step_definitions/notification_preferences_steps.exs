defmodule NotificationPreferencesSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import PhoenixTest

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
    assert switch_state(session(context), label) == "false"
    context
  end

  step "{string} is on", %{args: [label]} = context do
    assert switch_state(session(context), label) == "true"
    context
  end

  step "the always-sent list names {string}", %{args: [label]} = context do
    assert_has(session(context), "#always-sent li", text: label)
    context
  end

  step "{string} has no switch", %{args: [label]} = context do
    assert switch_state(session(context), label) == nil
    context
  end

  defp session(context), do: context[:session] || context[:conn]

  # Follow the visible label to its switch and read the switch's state:
  # "true" / "false", or nil when nothing labelled that way is a switch.
  defp switch_state(session, label) do
    document = Floki.parse_document!(page_html(session))

    document
    |> Floki.find("label")
    |> Enum.find(fn node -> String.trim(Floki.text(node)) == label end)
    |> case do
      nil ->
        nil

      node ->
        [id] = Floki.attribute(node, "for")

        case Floki.find(document, "##{id}[role=switch]") do
          [switch] -> switch |> Floki.attribute("aria-checked") |> List.first()
          [] -> nil
        end
    end
  end

  defp page_html(%PhoenixTest.Live{view: view}), do: Phoenix.LiveViewTest.render(view)
  defp page_html(%PhoenixTest.Static{conn: conn}), do: conn.resp_body
end
