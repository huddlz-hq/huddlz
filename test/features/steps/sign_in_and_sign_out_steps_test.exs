defmodule SignInAndSignOutStepsTest do
  use Cucumber, feature: "sign_in_and_sign_out.feature"
  use HuddlzWeb.WallabyCase

  # Step definitions using Wallaby
  defstep "the user is on the home page", context do
    session = context.session |> visit("/")
    {:ok, Map.put(context, :session, session)}
  end

  defstep "the user clicks the {string} link in the navbar", context do
    link_text = List.first(context.args)
    session = context.session |> click(link(link_text))
    {:ok, Map.put(context, :session, session)}
  end

  defstep "the user navigates to the sign in page", context do
    session = context.session |> visit("/sign-in")
    {:ok, Map.put(context, :session, session)}
  end

  defstep "the user enters a registered email address for magic link authentication", context do
    # Create user using generator
    user = generate(user())

    # Convert CiString to regular string for Wallaby
    email = to_string(user.email)

    # Wallaby expects fill_in to be called with the proper syntax
    session = context.session |> fill_in(text_field("Email"), with: email)

    {:ok, Map.merge(context, %{session: session, email: email, user: user})}
  end

  defstep "the user submits the sign in form", context do
    session = context.session |> click(button("Request magic link"))
    {:ok, Map.put(context, :session, session)}
  end

  defstep "the user receives a confirmation message", context do
    # Wallaby CAN see flash messages! Use role='alert' selector
    context.session
    |> assert_has(
      css("[role='alert']", text: "you will be contacted with a sign-in link shortly")
    )

    {:ok, context}
  end

  defstep "the user clicks the magic link in their email", context do
    # Get the magic link token from the email
    receive do
      {:email, %{to: [{_, email}], assigns: %{url: url}}} when email == context.email ->
        # Extract token from URL and visit the magic link
        session = context.session |> visit(url)
        {:ok, Map.put(context, :session, session)}
    after
      1000 ->
        raise "No email received"
    end
  end

  defstep "the user is redirected to the homepage", context do
    context.session |> assert_has(css("h1", text: "Find your huddl"))
    {:ok, context}
  end

  defstep "the user is logged in", context do
    # Check for user menu or sign out link
    context.session |> assert_has(link("Sign Out"))
    {:ok, context}
  end

  # Add more step definitions as needed...

  defstep "the user enters an email address for magic link authentication", context do
    session = context.session |> fill_in(text_field("Email"), with: "test@example.com")
    {:ok, Map.put(context, :session, session)}
  end

  defstep "the user sees a message indicating that a magic link was sent if the account exists",
          context do
    # Wallaby CAN see flash messages! Use role='alert' selector
    context.session
    |> assert_has(
      css("[role='alert']", text: "you will be contacted with a sign-in link shortly")
    )

    {:ok, context}
  end

  defstep "the user submits the sign in form without entering an email address", context do
    session = context.session |> click(button("Request magic link"))
    {:ok, Map.put(context, :session, session)}
  end

  defstep "the user remains on the sign in page", context do
    # Take screenshot to debug
    context.session
    |> take_screenshot(name: "remain_on_sign_in")

    # Check we're still on sign-in page - look for sign in form
    context.session
    |> assert_has(css("form"))
    |> assert_has(text_field("Email"))

    {:ok, context}
  end

  defstep "the user receives a magic link email", context do
    # In test environment, emails are captured rather than sent
    # This would need to be implemented based on your email testing setup
    {:ok, context}
  end
end
