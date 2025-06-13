defmodule SignInAndSignOutSteps do
  use Cucumber.StepDefinition
  import PhoenixTest
  import Phoenix.ConnTest, only: [build_conn: 0]

  # Step: When the user enters {string} in the email field
  step "the user enters {string} in the email field", %{args: [email]} = context do
    session = context[:session] || context[:conn]

    session =
      session
      |> within("#password-sign-in-form", fn session ->
        fill_in(session, "Email", with: email)
      end)

    Map.merge(context, %{session: session, email: email})
  end

  # Step: When the user enters {string} in the password field
  step "the user enters {string} in the password field", %{args: [password]} = context do
    session = context[:session] || context[:conn]

    session =
      session
      |> within("#password-sign-in-form", fn session ->
        fill_in(session, "Password", with: password)
      end)

    Map.merge(context, %{session: session, password: password})
  end

  # Step: When the user submits the password sign in form
  step "the user submits the password sign in form", context do
    session = context[:session] || context[:conn]

    session =
      session
      |> within("#password-sign-in-form", fn session ->
        click_button(session, "Sign in")
      end)

    Map.merge(context, %{session: session, conn: session})
  end

  # Step: When the user submits the password sign in form without entering an email address
  step "the user submits the password sign in form without entering an email address", context do
    # Visit sign-in page if not already there
    session = context[:session] || context[:conn] || build_conn() |> visit("/sign-in")

    # Try to submit with empty email
    session =
      session
      |> within("#password-sign-in-form", fn session ->
        click_button(session, "Sign in")
      end)

    Map.merge(context, %{session: session, conn: session})
  end

  # Step: Then the user should be signed in
  step "the user should be signed in", context do
    session = context[:session] || context[:conn]

    # Check that we're on the home page with a signed-in user
    assert_has(session, "a", text: "Profile")
    refute_has(session, "a", text: "Sign In")

    {:ok, context}
  end

  # Step: Then the user should not be signed in
  step "the user should not be signed in", context do
    session = context[:session] || context[:conn]

    # Check that we still see the sign in link
    assert_has(session, "a", text: "Sign In")
    refute_has(session, "a", text: "Profile")

    {:ok, context}
  end

  # Step: Then the user remains on the sign in page
  step "the user remains on the sign in page", context do
    # Check if we're still on the sign-in page by looking for sign-in form elements
    session = context[:session] || context[:conn]
    assert_has(session, "#password-sign-in-form")
    assert_has(session, "button", text: "Sign in")
    {:ok, context}
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
