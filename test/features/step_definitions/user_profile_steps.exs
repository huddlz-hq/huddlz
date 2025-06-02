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
    session = visit(context.session, "/profile")
    Map.put(context, :session, session)
  end

  # When steps
  step "I clear the {string} field", %{args: [field]} = context do
    session = fill_in(context.session, field, with: "")
    Map.put(context, :session, session)
  end

  # Then steps
  step "I should see my current display name", context do
    user = context[:current_user]
    assert_has(context.session, "*", text: user.display_name)
    context
  end

  step "I should see {string} badge", %{args: [badge_text]} = context do
    assert_has(context.session, ".badge", text: badge_text)
    context
  end

  step "the display name field should contain {string}", %{args: [expected_value]} = context do
    assert_has(context.session, "input[name=\"form[display_name]\"][value=\"#{expected_value}\"]")
    context
  end
end
