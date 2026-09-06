defmodule CurrentNavigationSteps do
  use Cucumber.StepDefinition

  import PhoenixTest

  step "navigation should identify {string} as the current destination",
       %{args: [label], session: session} = context do
    session
    |> assert_has(".sb-item.active[aria-current='page']", text: label)
    |> refute_has(".sb-item:not(.active)[aria-current]")

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
