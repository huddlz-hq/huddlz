defmodule UserProfileSteps do
  @moduledoc """
  Cucumber step definitions for user profile management features.
  """
  use Cucumber.StepDefinition
  import PhoenixTest
  import CucumberDatabaseHelper

  # Given steps
  step "I am on my profile page", context do
    ensure_sandbox()
    session = context[:session] || context[:conn]
    session = visit(session, "/profile")
    Map.merge(context, %{session: session, conn: session})
  end

  # When steps
  step "I clear the {string} field", %{args: [field]} = context do
    session = context[:session] || context[:conn]
    session = fill_in(session, field, with: "")
    Map.merge(context, %{session: session, conn: session})
  end

  # Then steps
  step "I should see my current display name", context do
    session = context[:session] || context[:conn]
    user = context[:current_user]
    assert_has(session, "*", text: user.display_name)
    context
  end

  step "I should see {string} badge", %{args: [badge_text]} = context do
    session = context[:session] || context[:conn]
    assert_has(session, ".badge", text: badge_text)
    context
  end

  step "the display name field should contain {string}", %{args: [expected_value]} = context do
    session = context[:session] || context[:conn]
    assert_has(session, "input[name=\"form[display_name]\"][value=\"#{expected_value}\"]")
    context
  end
end
