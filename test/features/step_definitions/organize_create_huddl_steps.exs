defmodule OrganizeCreateHuddlSteps do
  use Cucumber.StepDefinition
  import PhoenixTest

  step "{string} should be the selected group", %{args: [group_name]} = context do
    session = context[:session] || context[:conn]

    assert_has(
      session,
      "#workspace-group-select option[selected]",
      text: group_name
    )

    context
  end
end
