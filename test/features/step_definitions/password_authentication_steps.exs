defmodule PasswordAuthenticationSteps do
  use Cucumber.StepDefinition

  import PhoenixTest
  import Huddlz.Generator

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

    # Process each row as a key-value pair
    session =
      Enum.reduce(table_rows, session, fn [field, value], sess ->
        case field do
          "email" ->
            fill_in(sess, "#user-password-register-with-password_email", "Email", with: value)

          "password" ->
            fill_in(sess, "#user-password-register-with-password_password", "Password",
              with: value
            )

          "password_confirmation" ->
            fill_in(
              sess,
              "#user-password-register-with-password_password_confirmation",
              "Password Confirmation",
              with: value
            )

          _ ->
            sess
        end
      end)

    {:ok, Map.merge(context, %{session: session, conn: session})}
  end

  step "I fill in the password sign-in form with:", context do
    # Extract the table data from the context
    table_rows = context[:datatable][:raw] || context[:datatable][:rows] || []

    session = context[:session] || context[:conn]

    # Process each row as a key-value pair
    session =
      Enum.reduce(table_rows, session, fn [field, value], sess ->
        case field do
          "email" ->
            fill_in(sess, "#user-password-sign-in-with-password_email", "Email", with: value)

          "password" ->
            fill_in(sess, "#user-password-sign-in-with-password_password", "Password",
              with: value
            )

          _ ->
            sess
        end
      end)

    {:ok, Map.merge(context, %{session: session, conn: session})}
  end

  step "a user exists with email {string} and password {string}",
       %{args: [email, password]} = context do
    _user = generate(user_with_password(email: email, password: password))
    {:ok, context}
  end

  step "I am signed in as {string} without a password", %{args: [email]} = context do
    # Create user without password
    user = generate(user(email: email))

    # Generate token using proper method
    {:ok, token, _claims} = AshAuthentication.Jwt.token_for_user(user)

    session = context[:session] || context[:conn]

    session =
      session
      |> visit("/")
      |> click_link("Sign In")
      |> visit("/auth/user/magic_link?token=#{token}")

    {:ok, Map.merge(context, %{session: session, conn: session, current_user: user})}
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
      |> fill_in("#user-password-sign-in-with-password_email", "Email", with: email)
      |> fill_in("#user-password-sign-in-with-password_password", "Password", with: password)
      |> click_button("Sign in")

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

    # Fill in the password form fields using field IDs to be more specific
    session =
      Enum.reduce(table_rows, session, fn [field, value], sess ->
        case field do
          "current_password" ->
            fill_in(sess, "#form_current_password", "Current Password", with: value)

          "password" ->
            fill_in(sess, "#form_password", "New Password", with: value)

          "password_confirmation" ->
            fill_in(sess, "#form_password_confirmation", "Confirm New Password", with: value)

          _ ->
            sess
        end
      end)

    {:ok, Map.merge(context, %{session: session, conn: session})}
  end

  step "I should be signed in", context do
    session = context[:session] || context[:conn]
    # Check for user menu or sign out link
    assert_has(session, "a", text: "Sign Out")

    {:ok, context}
  end

  step "I should not be signed in", context do
    session = context[:session] || context[:conn]
    # Check that Sign Out link is NOT present
    refute_has(session, "a", text: "Sign Out")
    {:ok, context}
  end

  step "I should see the password sign-in form", context do
    session = context[:session] || context[:conn]
    assert_has(session, "input#user-password-sign-in-with-password_email")
    assert_has(session, "input#user-password-sign-in-with-password_password")
    {:ok, context}
  end

  step "I should see the magic link form", context do
    session = context[:session] || context[:conn]
    assert_has(session, "input#user-magic-link-request-magic-link_email")
    {:ok, context}
  end

  step "I should see the password registration form", context do
    session = context[:session] || context[:conn]
    assert_has(session, "input#user-password-register-with-password_email")
    assert_has(session, "input#user-password-register-with-password_password")
    {:ok, context}
  end

  step "I should see the magic link registration form", context do
    session = context[:session] || context[:conn]
    assert_has(session, "button", text: "Request magic link")
    {:ok, context}
  end
end
