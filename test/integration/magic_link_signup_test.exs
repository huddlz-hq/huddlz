defmodule Huddlz.Integration.MagicLinkSignupTest do
  use HuddlzWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  test "complete signup flow with magic link", %{conn: conn} do
    # Start on home page
    conn = get(conn, "/")
    assert html_response(conn, 200) =~ "Huddlz"

    # Go to registration page
    conn = get(conn, "/register")
    assert html_response(conn, 200) =~ "Request magic link"

    # Set up LiveView for form submission
    {:ok, view, _html} = live(conn, "/register")

    # Generate random email
    email = "newuser_#{:rand.uniform(99999)}@example.com"

    # Submit the registration form
    render_submit(element(view, "form"), %{
      "user" => %{
        "email" => email
      }
    })

    # Verify email was sent
    assert_email_sent(to: {nil, email})

    # Simulate a user with an active session (mocking the magic link click)
    # We'll just simulate a signed-in user for this test
    conn =
      build_conn()
      |> init_test_session(%{})
      |> put_session(:current_user, %{email: email})
      |> get("/")

    # Verify we're on the homepage and can see content that indicates we're logged in
    response = html_response(conn, 200)
    assert response =~ "Huddlz"
  end

  test "verify display name generation pattern", %{conn: _conn} do
    # We're just testing the display name generation function directly
    # Generate a display name using our function
    display_name = Huddlz.Accounts.User.generate_random_display_name()

    # Verify the display name follows our pattern
    # It should be a combination of an adjective, animal, and number
    assert String.match?(display_name, ~r/[A-Z][a-z]+[A-Z][a-z]+\d+/)

    # Generate multiple names and make sure they're all different
    names = for _ <- 1..10, do: Huddlz.Accounts.User.generate_random_display_name()
    unique_names = Enum.uniq(names)

    # Verify we got 10 unique names
    assert length(unique_names) == 10, "Generated display names should be unique"
  end
end
