defmodule DeleteHuddlSteps do
  use Cucumber.StepDefinition

  import PhoenixTest

  step "I confirm cancelling the huddl", context do
    session = context[:session] || context[:conn]

    session =
      within(session, "#cancel-huddl-modal", fn scoped ->
        click_button(scoped, "Cancel huddl")
      end)

    Map.merge(context, %{session: session, conn: session})
  end
end
