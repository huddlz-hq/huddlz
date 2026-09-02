defmodule SignedInHomeDestinationSteps do
  use Cucumber.StepDefinition

  import Phoenix.ConnTest, only: [build_conn: 0]
  import PhoenixTest

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
end
