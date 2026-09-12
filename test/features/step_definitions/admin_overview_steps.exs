defmodule AdminOverviewSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import PhoenixTest

  require Ash.Query

  alias Huddlz.Accounts.User

  step "I can change the role of {string}", %{args: [email], session: session} = context do
    session =
      session
      |> select("Role for #{email}", option: "Admin")
      |> click_button("Update role for #{email}")
      |> assert_has("*", text: "User role updated successfully")

    user = User |> Ash.Query.filter(email == ^email) |> Ash.read_one!(authorize?: false)
    assert user.role == :admin

    Map.merge(context, %{conn: session, session: session})
  end
end
