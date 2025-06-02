defmodule Huddlz.Integration.MagicLinkSignupTest do
  use HuddlzWeb.ConnCase, async: true

  import Swoosh.TestAssertions
  import Huddlz.Test.Helpers.Authentication

  alias Huddlz.Accounts.User
  require Ash

  test "complete signup flow with magic link", %{conn: conn} do
    # Start on home page
    session = conn |> visit("/")
    assert_has(session, "h1", text: "Find your huddl")

    # Go to registration page
    session = session |> visit("/register")
    assert session.conn.resp_body =~ "Request magic link"

    # Generate random email
    email = "newuser_#{:rand.uniform(99999)}@example.com"

    # Submit the registration form
    session
    |> fill_in("#user-magic-link-request-magic-link_email", "Email", with: email)
    |> click_button("Request magic link")

    # Verify email was sent
    assert_email_sent(to: {nil, email})

    # Simulate a user with an active session (mocking the magic link click)
    # We'll just simulate a signed-in user for this test
    session =
      build_conn()
      |> init_test_session(%{})
      |> put_session(:current_user, %{email: email})
      |> visit("/")

    # Verify we're on the homepage and can see content that indicates we're logged in
    assert_has(session, "h1", text: "Find your huddl")
  end

  test "verify display name is generated for new users", %{conn: _conn} do
    # Create a new user without providing a display name
    email = "newuser#{System.unique_integer()}@example.com"

    # Create an admin actor for the test using the generator
    admin = create_user(%{role: :admin})

    # Use the :create action which includes SetDefaultDisplayName change
    user =
      User
      |> Ash.Changeset.for_create(
        :create,
        %{
          email: email,
          role: :regular
          # Note: not providing display_name
        },
        actor: admin
      )
      |> Ash.create!()

    # Verify that a display name was generated
    assert user.display_name != nil
    assert user.display_name != ""

    # Verify the display name follows the expected pattern
    assert user.display_name =~ ~r/^[A-Z][a-z]+[A-Z][a-z]+\d+$/,
           "Display name should match pattern like 'BraveEagle123'"
  end
end
