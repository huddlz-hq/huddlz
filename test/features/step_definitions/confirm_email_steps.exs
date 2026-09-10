defmodule ConfirmEmailSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import PhoenixTest

  require Ash.Query

  alias Huddlz.Accounts.User

  step "I open the confirmation link sent to {string}", %{args: [email]} = context do
    body =
      receive do
        {:email,
         %Swoosh.Email{
           subject: "Confirm your email address",
           to: [{"", ^email}],
           html_body: body
         }} ->
          body
      after
        100 -> flunk("No confirmation email received for #{email}")
      end

    [url] = body |> Floki.parse_fragment!() |> Floki.attribute("a", "href")
    path = URI.parse(url).path
    session = visit(context.session, path)
    Map.merge(context, %{session: session, conn: session, confirm_path: path})
  end

  step "I open that confirmation link again", context do
    session = visit(context.session, context.confirm_path)
    Map.merge(context, %{session: session, conn: session})
  end

  step "I see a huddlz page asking me to confirm my email", %{session: session} = context do
    session
    |> assert_has("h1", text: "Confirm your email")
    |> assert_has("button", text: "Confirm my email")
    |> assert_has("a[href='/']", text: "huddlz")

    context
  end

  step "{string} is confirmed", %{args: [email]} = context do
    user = User |> Ash.Query.filter(email == ^email) |> Ash.read_one!(authorize?: false)
    assert user.confirmed_at, "expected #{email} to be confirmed"
    context
  end

  step "the page tells me the link no longer works and offers to sign in",
       %{session: session} = context do
    session
    |> assert_has(".auth-state", text: "This confirmation link no longer works")
    |> assert_has(".auth-state a[href='/sign-in']", text: "Sign in")

    context
  end
end
