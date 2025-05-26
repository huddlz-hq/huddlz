defmodule CompleteSignupFlowSteps do
  use Cucumber, feature: "complete_signup_flow.feature"
  use HuddlzWeb.ConnCase, async: true

  import Swoosh.TestAssertions

  # Step: Given the user is on the home page
  defstep "the user is on the home page", %{conn: conn} do
    session = conn |> visit("/")
    {:ok, Map.put(%{conn: conn}, :session, session)}
  end

  # Step: When the user clicks the "Sign Up" link in the navbar
  defstep "the user clicks the {string} link in the navbar",
          %{session: session, args: [link_text]} = context do
    session = session |> click_link(link_text)
    {:ok, Map.put(context, :session, session)}
  end

  # Step: And the user enters an unregistered email address
  defstep "the user enters an unregistered email address", context do
    # Generate a random email that doesn't exist in the system
    email = "newuser_#{:rand.uniform(99999)}@example.com"
    {:ok, Map.put(context, :email, email)}
  end

  # Step: And the user submits the sign up form
  defstep "the user submits the sign up form", %{session: session, email: email} = context do
    # Fill in email and submit form
    session =
      session
      |> fill_in("Email", with: email)
      |> click_button("Request magic link")

    {:ok, Map.put(context, :session, session)}
  end

  # Step: Then the user receives a confirmation message
  defstep "the user receives a confirmation message", %{session: session} = context do
    # Check for the specific confirmation message after requesting magic link
    session =
      assert_has(session, "*",
        text:
          "If this user exists in our database, you will be contacted with a sign-in link shortly."
      )

    {:ok, Map.put(context, :session, session)}
  end

  # Step: And the user receives a magic link email
  defstep "the user receives a magic link email", %{email: email_address} = context do
    magic_link =
      assert_email_sent(fn email ->
        assert email.to == [{"", email_address}]

        case Regex.run(~r{(https?://[^/]+/auth/[^\s"'<>]+)}, email.html_body) do
          [_, url] ->
            url

          _ ->
            raise "Magic link not found in email body"
        end
      end)

    {:ok, %{context: context, magic_link: magic_link}}
  end

  # Step: When the user clicks the magic link in the email
  defstep "the user clicks the magic link in the email", %{session: session} = context do
    session = session |> visit(context.magic_link)

    {:ok, Map.put(context, :session, session)}
  end

  # Step: Then the user is successfully signed in
  defstep "the user is successfully signed in", %{session: session} = context do
    session = assert_has(session, "a", text: "Sign Out")

    {:ok, Map.put(context, :session, session)}
  end

  # Step: And the user can see their personal dashboard
  defstep "the user can see their personal dashboard", %{session: session} = context do
    session = assert_has(session, "h1", text: "Find your huddl")

    {:ok, Map.put(context, :session, session)}
  end
end
