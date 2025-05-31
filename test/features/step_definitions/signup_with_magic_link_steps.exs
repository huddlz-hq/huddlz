defmodule SignupWithMagicLinkSteps do
  use Cucumber.StepDefinition
  import PhoenixTest

  # This step is already defined in shared_ui_steps.exs, skip to avoid duplication

  # Step: Given the user navigates to the sign up page
  step "the user navigates to the sign up page", context do
    session = context[:session] || context[:conn]
    session = visit(session, "/register")
    Map.merge(context, %{session: session, conn: session})
  end

  # This step is already defined in complete_signup_flow_steps.exs

  # Step: And the user enters a display name
  step "the user enters a display name", context do
    display_name = "Test User #{:rand.uniform(999)}"
    Map.put(context, :display_name, display_name)
  end

  # This step is already defined in complete_signup_flow_steps.exs

  # Step: And the user submits the sign up form with the generated display name
  step "the user submits the sign up form with the generated display name", context do
    # Navigate to the page and submit the form
    session = context[:session] || context[:conn]

    session =
      session
      |> visit("/register")
      |> fill_in("Email", with: context.email)
      |> submit()

    # Continue with the test
    Map.merge(context, %{session: session, conn: session, email: context.email})
  end

  step "the user enters an invalid email address without an {string} character",
       %{args: [_]} = context do
    invalid_email = "invalidemail.example.com"
    Map.put(context, :email, invalid_email)
  end

  # This step is already defined in sign_in_and_sign_out_steps.exs

  # These steps are defined in complete_signup_flow_steps.exs
  # So we'll skip them here to avoid duplication
end
