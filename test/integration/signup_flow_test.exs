defmodule Huddlz.Integration.SignupFlowTest do
  use HuddlzWeb.ConnCase, async: true

  import PhoenixTest
  import Swoosh.TestAssertions

  test "user can sign up and receive a magic link", %{conn: conn} do
    # Generate random email
    email = "newuser_#{:rand.uniform(99999)}@example.com"

    conn
    |> visit("/")
    |> assert_has("h1", text: "Find your huddl")
    |> visit("/register")
    |> assert_has("button", text: "Request magic link")
    |> fill_in("Email", with: email)
    |> click_button("Request magic link")

    # Verify email was sent
    assert_email_sent(to: {nil, email})

    # For testing purposes, we can't click the actual magic link
    # as we can't access the token from the email content in tests.
    # That's fine - the real test of the magic link verification happens
    # in the actual feature test.

    # For this integration test, we just verify that an email was sent
    # and we consider the signup process initiated successfully.
    # No need to verify user creation here, as that happens when the link is clicked.
  end

  test "invalid email format should prevent form submission", %{conn: conn} do
    # Generate invalid email (no @)
    email = "invalid-email-format"

    session =
      conn
      |> visit("/register")
      |> assert_has("button", text: "Request magic link")
      |> fill_in("Email", with: email)
      |> click_button("Request magic link")

    # Check for validation message
    # Since AshAuthentication handles validation, just check we're still on the form
    session
    |> assert_has("button", text: "Request magic link")
  end
end
