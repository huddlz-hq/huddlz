defmodule AgendaSearchSteps do
  @moduledoc """
  Steps for the agenda's one search affordance. The agenda lists only huddlz
  the person is already going to, so "not shown here" is the premise the
  search exists to solve. The last two steps are the variant's discipline
  check: the agenda gains exactly one affordance and no filters.
  """
  use Cucumber.StepDefinition

  import PhoenixTest

  step "the agenda does not show {string}", %{args: [title]} = context do
    session = context[:session] || context[:conn]
    refute_has(session, ".cal-agenda-title", text: title)
    context
  end

  step "the agenda offers one search affordance", context do
    session = context[:session] || context[:conn]
    assert_has(session, "#agenda-search input[type='search']", count: 1)
    context
  end

  step "the agenda offers no date or type filters", context do
    session = context[:session] || context[:conn]

    session
    |> refute_has("#agenda-search select")
    |> refute_has("#agenda-search input[type='checkbox']")
    |> refute_has("#agenda-search input[type='radio']")

    context
  end
end
