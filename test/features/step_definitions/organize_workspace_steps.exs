defmodule OrganizeWorkspaceSteps do
  use Cucumber.StepDefinition
  import PhoenixTest

  require Ash.Query

  step "the page should link {string} to its edit screen",
       %{args: [name]} = context do
    session = context[:session] || context[:conn]
    group = lookup_group(name)

    assert_has(session, "a[href='/groups/#{group.slug}/edit']", text: name)

    context
  end

  defp lookup_group(name) do
    Huddlz.Communities.Group
    |> Ash.Query.filter(name: name)
    |> Ash.read_one!(authorize?: false)
  end
end
