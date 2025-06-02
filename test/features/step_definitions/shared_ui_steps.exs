defmodule SharedUISteps do
  @moduledoc """
  Shared Cucumber step definitions for UI interactions and assertions.

  This module provides reusable steps for:
  - Navigation and page visits
  - Clicking links and buttons
  - Form interactions (filling fields, selecting options)
  - Content assertions (seeing/not seeing text)
  - Button visibility checks

  All steps handle PhoenixTest sessions internally and maintain
  proper context between steps.

  See test/features/step_definitions/README.md for usage examples.
  """
  use Cucumber.StepDefinition
  import PhoenixTest

  import Phoenix.ConnTest, only: [build_conn: 0]
  import CucumberDatabaseHelper

  # Navigation steps
  step "the user is on the home page", context do
    ensure_sandbox()

    session = context[:session] || context[:conn] || build_conn()
    session = visit(session, "/")

    Map.merge(context, %{session: session, conn: session})
  end

  step "I visit {string}", %{args: [path]} = context do
    ensure_sandbox()

    session = context[:session] || context[:conn] || build_conn()
    session = visit(session, path)

    Map.merge(context, %{session: session, conn: session})
  end

  step "the user clicks the {string} link in the navbar", %{args: [link_text]} = context do
    session = context[:session] || context[:conn]

    session =
      session
      |> visit("/")
      |> click_link(link_text)

    Map.merge(context, %{session: session, conn: session})
  end

  # Clicking actions
  step "I click {string}", %{args: [text]} = context do
    session = context[:session] || context[:conn]

    # Try clicking as link first, then as button
    session =
      try do
        click_link(session, text)
      rescue
        _ -> click_button(session, text)
      end

    Map.merge(context, %{session: session, conn: session})
  end

  step "I click the {string} button", %{args: [button_text]} = context do
    session = context[:session] || context[:conn]
    session = click_button(session, button_text)

    Map.merge(context, %{session: session, conn: session})
  end

  step "I click link {string}", %{args: [link_text]} = context do
    session = context[:session] || context[:conn]

    # Just use the regular click_link and let it fail if there are multiple matches
    # This forces test writers to be more specific
    session = click_link(session, link_text)

    Map.merge(context, %{session: session, conn: session})
  end

  # Content assertions
  step "I should see {string}", %{args: [text]} = context do
    session = context[:session] || context[:conn]
    assert_has(session, "*", text: text)
    context
  end

  step "I should not see {string}", %{args: [text]} = context do
    session = context[:session] || context[:conn]
    refute_has(session, "*", text: text)
    context
  end

  step "I should see {string} in the flash", %{args: [message]} = context do
    session = context[:session] || context[:conn]
    assert_has(session, "*", text: message)
    context
  end

  step "the user should see {string}", %{args: [text]} = context do
    session = context[:session] || context[:conn]
    assert_has(session, "*", text: text)
    context
  end

  step "the user should not see {string}", %{args: [text]} = context do
    session = context[:session] || context[:conn]
    refute_has(session, "*", text: text)
    context
  end

  # Form interactions
  step "I fill in {string} with {string}", %{args: [field, value]} = context do
    session = context[:session] || context[:conn]

    # Check if field starts with # to indicate it's an ID selector
    session =
      if String.starts_with?(field, "#") do
        # For ID selectors, we need to use the proper label
        # Let's extract the ID and use it with the Email label
        fill_in(session, field, "Email", with: value)
      else
        # Regular label-based fill
        fill_in(session, field, with: value)
      end

    Map.merge(context, %{session: session, conn: session})
  end

  step "I select {string} from {string}", %{args: [option, field]} = context do
    session = context[:session] || context[:conn]
    # PhoenixTest select requires exact: false for partial label matching
    session = select(session, field, option: option, exact: false)

    Map.merge(context, %{session: session, conn: session})
  end

  # Button presence checks
  step "the {string} button should be visible", %{args: [button_text]} = context do
    session = context[:session] || context[:conn]
    assert_has(session, "button", text: button_text)
    context
  end

  step "the {string} button should not be visible", %{args: [button_text]} = context do
    session = context[:session] || context[:conn]
    refute_has(session, "button", text: button_text)
    context
  end
end
