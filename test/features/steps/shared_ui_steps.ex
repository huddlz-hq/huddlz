defmodule Huddlz.Test.Features.Steps.SharedUISteps do
  @moduledoc """
  Shared UI and navigation step definitions for Cucumber tests.

  This module provides common UI interaction steps that can be imported
  into any Cucumber test file to standardize navigation, clicking, and
  content assertion patterns.

  ## Usage

      defmodule MyFeatureTest do
        use Huddlz.DataCase
        use Cucumber, feature: "my_feature.feature"
        use Huddlz.Test.Features.Steps.SharedUISteps
        
        # Your specific step definitions...
      end
  """

  use Cucumber.SharedSteps

  @doc """
  Clicks on a link or button with the given text.
  Tries as a link first, then falls back to button.

  Example usage in feature file:

      When I click "Sign In"
      And I click "Create Group"
  """
  defstep "I click {string}", %{args: [text]} = context do
    session =
      try do
        # Try as a link first
        click_link(context.session, text)
      rescue
        _ ->
          # Fall back to button
          click_button(context.session, text)
      end

    {:ok, Map.put(context, :session, session)}
  end

  @doc """
  Asserts that the given text is visible on the page.

  Example usage in feature file:

      Then I should see "Welcome to Huddlz"
      And I should see "Your group has been created"
  """
  defstep "I should see {string}", %{args: [text]} = context do
    session = assert_has(context.session, "*", text: text)
    {:ok, Map.put(context, :session, session)}
  end

  @doc """
  Asserts that the given text appears in a flash message.
  This is the standard way to check flash messages.

  Example usage in feature file:

      Then I should see "Successfully created!" in the flash
      And I should see "Welcome back!" in the flash
  """
  defstep "I should see {string} in the flash", %{args: [text]} = context do
    # Flash messages are typically in role="alert" or class="alert"
    session = assert_has(context.session, "[role='alert']", text: text)
    {:ok, Map.put(context, :session, session)}
  end

  @doc """
  Visits a specific path.

  Example usage in feature file:

      When I visit "/"
      And I visit "/groups"
  """
  defstep "I visit {string}", %{args: [path]} = context do
    session = visit(context.session, path)
    {:ok, Map.put(context, :session, session)}
  end

  @doc """
  Navigates to the home page.

  Example usage in feature file:

      Given I am on the home page
      When the user is on the home page
  """
  defstep "I am on the home page", context do
    session = visit(context.session, "/")
    {:ok, Map.put(context, :session, session)}
  end

  defstep "the user is on the home page", context do
    session = visit(context.session, "/")
    {:ok, Map.put(context, :session, session)}
  end

  @doc """
  Clicks a link in the navbar.

  Example usage in feature file:

      When the user clicks the "Groups" link in the navbar
      And I click the "Sign Out" link in the navbar
  """
  defstep "the user clicks the {string} link in the navbar", %{args: [link_text]} = context do
    # Navbar links are typically in nav elements
    session =
      within(context.session, "nav", fn session ->
        click_link(session, link_text)
      end)

    {:ok, Map.put(context, :session, session)}
  end

  defstep "I click the {string} link in the navbar", %{args: [link_text]} = context do
    session =
      within(context.session, "nav", fn session ->
        click_link(session, link_text)
      end)

    {:ok, Map.put(context, :session, session)}
  end

  @doc """
  Fills in a form field.

  Example usage in feature file:

      When I fill in "Email" with "user@example.com"
      And I fill in "Name" with "Test Group"
  """
  defstep "I fill in {string} with {string}", %{args: [field, value]} = context do
    session = fill_in(context.session, field, with: value)
    {:ok, Map.put(context, :session, session)}
  end

  @doc """
  Submits a form.

  Example usage in feature file:

      When I submit the form
  """
  defstep "I submit the form", context do
    session = submit_form(context.session, "form")
    {:ok, Map.put(context, :session, session)}
  end

  @doc """
  Checks for the presence of a specific button.

  Example usage in feature file:

      Then I should see a "Create Group" button
      And I should see a "Sign In" button
  """
  defstep "I should see a {string} button", %{args: [button_text]} = context do
    session = assert_has(context.session, "button", text: button_text)
    {:ok, Map.put(context, :session, session)}
  end

  @doc """
  Checks for the absence of specific text.

  Example usage in feature file:

      Then I should not see "Error"
      And I should not see "Failed"
  """
  defstep "I should not see {string}", %{args: [text]} = context do
    refute_has(context.session, "*", text: text)
    {:ok, context}
  end
end
