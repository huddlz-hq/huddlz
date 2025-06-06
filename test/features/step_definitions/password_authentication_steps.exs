defmodule PasswordAuthenticationSteps do
  use Cucumber.StepDefinition

  import PhoenixTest
  import Huddlz.Generator
  import ExUnit.Assertions

  step "I am on the registration page", context do
    session = context[:session] || context[:conn]
    session = session |> visit("/register")
    {:ok, Map.merge(context, %{session: session, conn: session})}
  end

  step "I am on the sign-in page", context do
    session = context[:session] || context[:conn]
    session = session |> visit("/sign-in")
    {:ok, Map.merge(context, %{session: session, conn: session})}
  end

  step "I fill in the password registration form with:", context do
    # Extract the table data from the context
    table_rows = context[:datatable][:raw] || context[:datatable][:rows] || []

    session = context[:session] || context[:conn]

    # Process each row as a key-value pair using the registration form
    session =
      within(session, "#registration-form", fn sess ->
        Enum.reduce(table_rows, sess, fn [field, value], s ->
          case field do
            "email" ->
              fill_in(s, "Email", with: value)

            "password" ->
              fill_in(s, "Password", with: value)

            "password_confirmation" ->
              fill_in(s, "Confirm Password", with: value)

            _ ->
              s
          end
        end)
      end)

    {:ok, Map.merge(context, %{session: session, conn: session})}
  end

  step "I fill in the password sign-in form with:", context do
    # Extract the table data from the context
    table_rows = context[:datatable][:raw] || context[:datatable][:rows] || []

    session = context[:session] || context[:conn]

    # Process each row as a key-value pair using the password sign-in form
    session =
      within(session, "#password-sign-in-form", fn sess ->
        Enum.reduce(table_rows, sess, fn [field, value], s ->
          case field do
            "email" ->
              fill_in(s, "Email", with: value)

            "password" ->
              fill_in(s, "Password", with: value)

            _ ->
              s
          end
        end)
      end)

    {:ok, Map.merge(context, %{session: session, conn: session})}
  end

  step "a user exists with email {string} and password {string}",
       %{args: [email, password]} = context do
    _user = generate(user_with_password(email: email, password: password))
    {:ok, context}
  end

  step "I am signed in as {string} without a password", %{args: [email]} = context do
    session = context[:session] || context[:conn]

    # Go to sign-in page and request magic link
    session =
      session
      |> visit("/sign-in")
      |> within("#magic-link-form", fn s ->
        s
        |> fill_in("Email", with: email)
        |> click_button("Request magic link")
      end)

    # Capture the magic link email
    magic_link =
      Swoosh.TestAssertions.assert_email_sent(fn sent_email ->
        assert sent_email.to == [{"", email}]

        case Regex.run(~r{(https?://[^/]+/auth/[^\s"'<>]+)}, sent_email.html_body) do
          [_, url] -> url
          _ -> raise "Magic link not found in email body"
        end
      end)

    # Visit the magic link to complete sign-in
    session = session |> visit(magic_link)

    {:ok, Map.merge(context, %{session: session, conn: session})}
  end

  step "I am signed in as {string} with password {string}",
       %{args: [email, password]} = context do
    # Create user with password
    user = generate(user_with_password(email: email, password: password))

    session = context[:session] || context[:conn]
    # Sign in
    session =
      session
      |> visit("/sign-in")
      |> within("#password-sign-in-form", fn s ->
        s
        |> fill_in("Email", with: email)
        |> fill_in("Password", with: password)
        |> click_button("Sign in")
      end)

    # Follow redirect to home page after successful sign-in
    session = visit(session, "/")

    {:ok, Map.merge(context, %{session: session, conn: session, current_user: user})}
  end

  step "I go to my profile page", context do
    session = context[:session] || context[:conn]
    session = session |> visit("/profile")
    {:ok, Map.merge(context, %{session: session, conn: session})}
  end

  step "I fill in the password form with:", context do
    # Extract the table data from the context
    table_rows = context[:datatable][:raw] || context[:datatable][:rows] || []

    session = context[:session] || context[:conn]

    # Use within to scope to the password form by its ID
    session =
      within(session, "#password-form", fn sess ->
        Enum.reduce(table_rows, sess, fn [field, value], s ->
          case field do
            "current_password" ->
              fill_in(s, "Current Password", with: value)

            "password" ->
              fill_in(s, "New Password", with: value)

            "password_confirmation" ->
              fill_in(s, "Confirm New Password", with: value)

            _ ->
              s
          end
        end)
      end)

    {:ok, Map.merge(context, %{session: session, conn: session})}
  end

  step "I submit the password form", context do
    session = context[:session] || context[:conn]

    # Click the submit button which should submit the form
    session = click_button(session, "Set Password")

    {:ok, Map.merge(context, %{session: session, conn: session})}
  end

  step "I submit the password sign-in form", context do
    session = context[:session] || context[:conn]

    # Click the sign in button within the password form
    session =
      within(session, "#password-sign-in-form", fn s ->
        click_button(s, "Sign in")
      end)

    # PhoenixTest should handle redirects automatically
    {:ok, Map.merge(context, %{session: session, conn: session})}
  end

  step "I should be signed in", context do
    session = context[:session] || context[:conn]
    
    # The old test just checked for "Sign Out" link
    # Our custom navigation has it in a dropdown menu
    assert_has(session, "a", text: "Sign Out")

    {:ok, Map.merge(context, %{session: session, conn: session})}
  end

  step "I should not be signed in", context do
    session = context[:session] || context[:conn]
    # Check that Sign Out link is NOT present
    refute_has(session, "a", text: "Sign Out")
    {:ok, context}
  end

  step "I should see the password sign-in form", context do
    session = context[:session] || context[:conn]
    assert_has(session, "form#password-sign-in-form")
    assert_has(session, "h2", text: "Sign in with password")
    {:ok, context}
  end

  step "I should see the magic link form", context do
    session = context[:session] || context[:conn]
    assert_has(session, "form#magic-link-form")
    assert_has(session, "h2", text: "Sign in with magic link")
    {:ok, context}
  end

  step "I should see the password registration form", context do
    session = context[:session] || context[:conn]
    assert_has(session, "form#registration-form")
    assert_has(session, "input#user_email")
    assert_has(session, "input#user_password")
    assert_has(session, "input#user_password_confirmation")
    {:ok, context}
  end

  step "I should see the magic link registration form", context do
    session = context[:session] || context[:conn]
    assert_has(session, "button", text: "Request magic link")
    {:ok, context}
  end
end
