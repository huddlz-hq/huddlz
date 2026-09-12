defmodule AuditHistorySteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  require Ash.Query

  step "the history remembers the title change by {string}",
       %{args: [email], current_huddl: huddl} = context do
    owner = Enum.find(context.users, &(to_string(&1.email) == email))

    versions =
      Huddlz.Communities.Huddl.Version
      |> Ash.Query.filter(version_source_id == ^huddl.id)
      |> Ash.read!(authorize?: false)

    assert Enum.any?(versions, fn version ->
             version.actor_id == owner.id and
               version.changes["title"] == "Corrected title"
           end)

    assert Enum.any?(versions, &(&1.changes["title"] == "Original title"))
    context
  end
end
