defmodule AgendaHomeSteps do
  use Cucumber.StepDefinition

  import PhoenixTest

  step "the user lands on the agenda", context do
    session = context[:session] || context[:conn]
    on_agenda(session)
    context
  end

  step "navigation offers no {string} destination",
       %{args: [label], session: session} = context do
    refute_has(session, ".sb-item .label", text: label, exact: true)
    context
  end

  step "navigation offers {string}", %{args: [label], session: session} = context do
    assert_has(session, ".sb-item .label", text: label, exact: true)
    context
  end

  step "the page heading is {string}", %{args: [heading], session: session} = context do
    assert_has(session, "h1", text: heading, exact: true)
    context
  end

  step "the agenda offers the {string} and {string} filters",
       %{args: [mine, groups], session: session} = context do
    session
    |> assert_has("#calendar-scope-mine", text: mine)
    |> assert_has("#calendar-scope-groups", text: groups)

    context
  end

  step "the page offers no view switcher", %{session: session} = context do
    refute_has(session, ".cal-view-tabs")
    context
  end

  step "the view choices are {string} and {string}",
       %{args: [first, second], session: session} = context do
    session
    |> assert_has(".cal-view-tabs .scope-tab", count: 2)
    |> assert_has(".cal-view-tabs .scope-tab", text: first, exact: true)
    |> assert_has(".cal-view-tabs .scope-tab", text: second, exact: true)

    context
  end

  defp on_agenda(session) do
    session
    |> assert_path("/agenda")
    |> assert_has("h1", text: "Agenda", exact: true)
  end
end
