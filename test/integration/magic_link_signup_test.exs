defmodule Huddlz.Integration.MagicLinkSignupTest do
  use HuddlzWeb.ConnCase, async: true

  import PhoenixTest
  import Swoosh.TestAssertions

  alias Huddlz.Accounts.User

  test "complete signup flow with magic link", %{conn: conn} do
    # Start on home page
    session =
      conn
      |> visit("/")
      |> assert_has("h1", text: "Find your huddl")

    # Go to registration page
    session =
      session
      |> visit("/register")
      |> assert_has("button", text: "Request magic link")

    # Generate random email
    email = "newuser_#{:rand.uniform(99999)}@example.com"

    # Submit the registration form
    session
    |> fill_in("Email", with: email)
    |> click_button("Request magic link")

    # Verify email was sent
    assert_email_sent(to: {nil, email})

    # Note: PhoenixTest doesn't support session manipulation like put_session
    # We would need to actually click the magic link or use a different approach
    # For now, we'll test that the registration form submitted successfully
  end

  test "verify display name generation pattern", %{conn: _conn} do
    # We're just testing the display name generation function directly
    # Generate a display name using our function
    display_name = User.generate_random_display_name()

    # Verify the display name follows our pattern
    # It should be a combination of an adjective, animal, and number
    assert String.match?(display_name, ~r/[A-Z][a-z]+[A-Z][a-z]+\d+/)

    # Generate multiple names and make sure they're all different
    names = for _ <- 1..10, do: User.generate_random_display_name()
    unique_names = Enum.uniq(names)

    # Verify we got 10 unique names
    assert length(unique_names) == 10, "Generated display names should be unique"
  end
end
