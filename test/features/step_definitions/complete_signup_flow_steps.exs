defmodule CompleteSignupFlowSteps do
  use Cucumber.StepDefinition
  import PhoenixTest
  import Swoosh.TestAssertions
  import ExUnit.Assertions

  # Step: And the user enters an unregistered email address
  step "the user enters an unregistered email address", context do
    # Generate a random email that doesn't exist in the system
    email = "newuser_#{:rand.uniform(99999)}@example.com"
    Map.put(context, :email, email)
  end

  # Step: And the user submits the sign up form
  step "the user submits the sign up form", context do
    session = context[:session] || context[:conn]

    # Submit the magic link form (available on both registration and sign-in pages)
    session =
      session
      |> within("#magic-link-form", fn session ->
        session
        |> fill_in("Email", with: context.email)
        |> click_button("Request magic link")
      end)

    Map.merge(context, %{session: session, conn: session})
  end

  # Step: Then the user receives a confirmation message
  step "the user receives a confirmation message", context do
    # Check for the magic link confirmation message
    session = context[:session] || context[:conn]

    assert_has(session, "*",
      text:
        "If this user exists in our database, you will be contacted with a sign-in link shortly."
    )

    context
  end

  # Step: And the user receives a magic link email
  step "the user receives a magic link email", context do
    magic_link =
      assert_email_sent(fn email ->
        assert email.to == [{"", context.email}]

        case Regex.run(~r{(https?://[^/]+/auth/[^\s"'<>]+)}, email.html_body) do
          [_, url] ->
            url

          _ ->
            raise "Magic link not found in email body"
        end
      end)

    Map.put(context, :magic_link, magic_link)
  end

  # Step: When the user clicks the magic link in the email
  step "the user clicks the magic link in the email", context do
    session = context[:session] || context[:conn]

    # Visit the magic link URL
    session = session |> visit(context.magic_link)

    Map.merge(context, %{session: session, conn: session})
  end

  # Step: Then the user is successfully signed in
  step "the user is successfully signed in", context do
    session = context[:session] || context[:conn]
    assert_has(session, "a", text: "Sign Out")
    context
  end

  # Step: And the user can see their personal dashboard
  step "the user can see their personal dashboard", context do
    session = context[:session] || context[:conn]
    assert_has(session, "h1", text: "Find your huddl")
    context
  end
end
