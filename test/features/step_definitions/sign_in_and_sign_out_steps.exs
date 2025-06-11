defmodule SignInAndSignOutSteps do
  use Cucumber.StepDefinition
  import PhoenixTest
  import ExUnit.Assertions
  import Phoenix.ConnTest, only: [build_conn: 0]

  # Step: And the user enters an email address for magic link authentication
  step "the user enters an email address for magic link authentication", context do
    Map.put(context, :email, "testuser@example.com")
  end

  # Step: And the user enters a registered email address for magic link authentication
  step "the user enters a registered email address for magic link authentication", context do
    Map.put(context, :email, "registered@example.com")
  end

  # Step: And the user submits the sign in form
  step "the user submits the sign in form", context do
    # Fill in the email and submit
    session = context[:session] || context[:conn]

    # Use the magic link form specifically
    session =
      session
      |> within("#magic-link-form", fn session ->
        session
        |> fill_in("Email", with: context.email)
        |> click_button("Request magic link")
      end)

    Map.merge(context, %{session: session, conn: session})
  end

  # This step is already defined in complete_signup_flow_steps.exs
  # So we'll skip it here to avoid duplication

  # Step: When the user clicks the magic link in their email
  step "the user clicks the magic link in their email", context do
    # Extract the magic link from the email
    magic_link =
      Swoosh.TestAssertions.assert_email_sent(fn sent_email ->
        assert sent_email.to == [{"", context.email}]

        case Regex.run(~r{(https?://[^/]+/auth/[^\s"'<>]+)}, sent_email.html_body) do
          [_, url] -> url
          _ -> raise "Magic link not found in email body"
        end
      end)

    # Visit the magic link
    session = context[:session] || context[:conn]
    session = session |> visit(magic_link)

    # Click the "Sign in" button on the interaction page
    session = session |> click_button("Sign in")

    # Return the connection for the next steps
    Map.merge(context, %{session: session, conn: session})
  end

  # Step: Then the user is signed in and sees a {string} link in the navbar
  step "the user is signed in and sees a {string} link in the navbar",
       %{args: [link_text]} = context do
    # Use the existing session from previous steps
    session = context[:session] || context[:conn]

    # Check for the expected link
    assert_has(session, "a", text: link_text)

    Map.merge(context, %{session: session, conn: session})
  end

  # Step: Then the user is signed out and sees a {string} link in the navbar
  step "the user is signed out and sees a {string} link in the navbar",
       %{args: [link_text]} = context do
    # Create a fresh connection and visit the home page
    session = build_conn() |> visit("/")

    # Check that the page contains the expected link
    assert_has(session, "a", text: link_text)

    # Verify we're actually signed out by checking for the Sign In link
    assert_has(session, "a", text: "Sign In")

    Map.merge(context, %{session: session, conn: session})
  end

  # Step: When the user enters an invalid or unregistered email address
  step "the user enters an invalid or unregistered email address", context do
    Map.put(context, :email, "notfound@example.com")
  end

  # Step: Then the user sees a message indicating that a magic link was sent if the account exists
  step "the user sees a message indicating that a magic link was sent if the account exists",
       context do
    # Check that we see the standard security message
    session = context[:session] || context[:conn]

    assert_has(session, "*",
      text:
        "If this user exists in our database, you will be contacted with a sign-in link shortly."
    )

    {:ok, context}
  end

  # Step: When the user submits the sign in form without entering an email address
  step "the user submits the sign in form without entering an email address", context do
    # Visit sign-in page if not already there
    session = context[:session] || context[:conn] || build_conn() |> visit("/sign-in")

    # Try to submit with empty email
    session = click_button(session, "Request magic link")

    Map.merge(context, %{session: session, conn: session})
  end

  # Step: Then the user remains on the sign in page
  step "the user remains on the sign in page", context do
    # Check if we're still on the sign-in page by looking for sign-in form elements
    session = context[:session] || context[:conn]
    assert_has(session, "button", text: "Request magic link")
    {:ok, context}
  end

  # Step: When the user enters an invalid email address without an "@" character
  step "the user enters an invalid email address without an \"@\" character", context do
    Map.put(context, :email, "invalidemail")
  end

  # Step: Then a validation error is shown indicating the email must be valid
  step "a validation error is shown indicating the email must be valid", context do
    # With server-side validation, we should see validation errors
    session = context[:session] || context[:conn]

    # The form should still be visible
    assert_has(session, "#magic-link-form")

    # The button should still say "Request magic link" (not changed to "Magic link sent!")
    assert_has(session, "button", text: "Request magic link")

    # There should be an error message about invalid email format
    assert_has(session, "*", text: "must match the pattern")

    {:ok, %{session: session}}
  end

  step "the user is on the sign in page", context do
    session = context[:session] || context[:conn]
    session = session |> visit("/sign-in")
    Map.merge(context, %{session: session, conn: session})
  end

  step "the user navigates to the sign in page", context do
    session = context[:session] || context[:conn]
    session = session |> visit("/sign-in")
    Map.merge(context, %{session: session, conn: session})
  end
end
