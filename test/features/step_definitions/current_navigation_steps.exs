defmodule CurrentNavigationSteps do
  use Cucumber.StepDefinition

  import PhoenixTest

  step "I choose the {string} view", %{args: [label], session: session} = context do
    Map.put(context, :session, click_link(session, ".scope-tab", label))
  end

  step "navigation should identify {string} as the current destination",
       %{args: [label], session: session} = context do
    session
    |> assert_has(".sb-item.active[aria-current='page']", text: label)
    |> refute_has(".sb-item:not(.active)[aria-current]")

    context
  end

  step "navigation should identify {string} under group {string} as the current destination",
       %{args: [section, group_name], session: session} = context do
    session
    |> assert_has(".sb-org-row.active", text: group_name)
    |> assert_has(".sb-sub-item.active[aria-current='page']", text: section, exact: true)
    |> refute_has(".sb-item[aria-current]")
    |> refute_has(".sb-org-row[aria-current]")

    context
  end

  step "view choices should identify {string} as current",
       %{args: [label], session: session} = context do
    session
    |> assert_has(".scope-tab.is-active[aria-current='page']", text: label)
    |> refute_has(".scope-tab:not(.is-active)[aria-current]")

    context
  end
end
