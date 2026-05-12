defmodule GlobalHeaderSteps do
  use Cucumber.StepDefinition
  import PhoenixTest

  step "the v3 topbar should expose a search form posting q to /discover", context do
    session = context[:session] || context[:conn]

    session
    |> assert_has(".content-topbar form[action='/discover'][method='get']")
    |> assert_has(".content-topbar input[type='search'][name='q'][placeholder='Search huddlz']")

    context
  end
end
