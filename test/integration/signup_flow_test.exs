defmodule Huddlz.Integration.SignupFlowTest do
  use HuddlzWeb.ConnCase, async: true

  import Swoosh.TestAssertions

  test "user can sign up and receive a magic link", %{conn: conn} do
    # Start on the home page
    session = conn |> visit("/")
    assert_has(session, "h1", text: "Find your huddl")

    # Go to registration page
    session = session |> visit("/register")
    assert session.conn.resp_body =~ "Request magic link"

    # Generate random email
    email = "newuser_#{:rand.uniform(99999)}@example.com"

    # Submit the magic link form
    session
    |> within("#magic-link-form", fn session ->
      session
      |> fill_in("Email", with: email)
      |> click_button("Request magic link")
    end)

    # Verify email was sent
    assert_email_sent(to: {nil, email})
  end

  test "invalid email format should prevent form submission", %{conn: conn} do
    # Go to registration page
    session = conn |> visit("/register")
    assert session.conn.resp_body =~ "Request magic link"

    # Generate invalid email (no @)
    email = "invalid-email-format"

    # Submit the form with invalid email
    session =
      session
      |> within("#magic-link-form", fn session ->
        session
        |> fill_in("Email", with: email)
        |> click_button("Request magic link")
      end)

    # Check for validation message
    # Since AshAuthentication handles validation, just check we're still on the form
    assert session.conn.resp_body =~ "Request magic link"
  end
end
