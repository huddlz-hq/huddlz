defmodule SignedInHomeDestinationSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Phoenix.ConnTest, only: [build_conn: 0]
  import PhoenixTest

  step "I have no group memberships", %{current_user: user} = context do
    assert Huddlz.Communities.get_by_user!(actor: user) == []
    context
  end

  step "I have no Personal huddlz", %{current_user: user} = context do
    assert_no_personal_huddlz!(user)

    context
  end

  step "I am not signed in", context do
    Map.put(context, :session, build_conn())
  end

  step "I visit the application root", %{session: session} = context do
    Map.put(context, :session, visit(session, "/"))
  end

  step "I am taken to Calendar", %{session: session} = context do
    assert_path(session, "/calendar")
    context
  end

  step "I see the existing anonymous landing page", %{session: session} = context do
    assert_has(session, ".land-hero", text: "Find your people.")
    context
  end

  defp assert_no_personal_huddlz!(user) do
    first_supported_datetime = ~U[0000-01-01 00:00:00Z]
    last_supported_datetime = ~U[9999-12-31 23:59:59Z]

    assert Huddlz.Communities.list_calendar_huddlz!(
             first_supported_datetime,
             last_supported_datetime,
             actor: user
           ) == []
  end
end
