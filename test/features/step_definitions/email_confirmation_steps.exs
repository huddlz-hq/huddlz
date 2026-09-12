defmodule EmailConfirmationSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import HuddlzWeb.ApiCase
  import Phoenix.ConnTest, only: [build_conn: 0, json_response: 2]
  import PhoenixTest
  import Swoosh.TestAssertions

  require Ash.Query

  alias AshAuthentication.Jwt
  alias Huddlz.Accounts.{Confirmation, Token, User}
  alias Huddlz.Accounts.User.Changes.LimitResends

  @resend_query ~s|mutation($id: ID!) { resendConfirmation(id: $id) { result { id } errors { message } } }|

  step "{string} has not confirmed their address", %{args: [email]} = context do
    email |> find_user() |> Ash.Seed.update!(%{confirmed_at: nil})
    context
  end

  step "resend limits are enforced", context do
    Huddlz.RateLimitTestHelper.enable_rate_limiting()
    context
  end

  step "I am told to confirm my address {string}", %{args: [email], session: session} = context do
    session
    |> assert_has("[role='region'][aria-label='Email confirmation']", text: "Confirm your email")
    |> assert_has("[role='region'][aria-label='Email confirmation']", text: email)

    context
  end

  step "I am not told to confirm my address", %{session: session} = context do
    refute_has(session, "[role='region'][aria-label='Email confirmation']")
    context
  end

  step "I am offered to resend the confirmation", %{session: session} = context do
    assert_has(session, "button", text: "Resend")
    context
  end

  step "I hide the confirmation reminder", %{session: session} = context do
    session = session |> visit("/agenda") |> click_button("Hide until next time")
    Map.merge(context, %{conn: session, session: session})
  end

  step "I sign out and sign in again as {string} with password {string}",
       %{args: [email, password], session: session} = context do
    session =
      session
      |> click_link("Sign out")
      |> click_link("Sign in")
      |> fill_in("Email", with: email)
      |> fill_in("Password", with: password)
      |> click_button("Sign in")
      |> assert_has("[role=alert]", text: "You are now signed in")

    Map.merge(context, %{conn: session, session: session})
  end

  step "my email is shown as {string}", %{args: [status], session: session} = context do
    assert_has(session, "#email-confirmation-status", text: status, exact: true)
    context
  end

  step "I ask for the confirmation email again", %{session: session} = context do
    session = session |> visit("/agenda") |> click_button("Resend email")
    Map.merge(context, %{conn: session, session: session})
  end

  step "I asked for the confirmation email a moment ago", context do
    resend!(me(context))
    # That email went out; the scenario is about the next request.
    assert_email_sent()
    context
  end

  step "I asked for the confirmation email an hour ago", context do
    {:ok, token} = Confirmation.mint(me(context))
    Map.put(context, :earlier_link, token)
  end

  step "{string} asked for the confirmation email five times this hour",
       %{args: [email]} = context do
    # Spread over the hour, so the minute window is clear.
    {limit, per} = LimitResends.window(:hour)
    key = LimitResends.key(find_user(email).id, :hour)
    {:allow, 5} = Huddlz.RateLimit.hit(key, per, limit, 5)
    context
  end

  step "{string} asks for the confirmation email through the API twice at once",
       %{args: [email]} = context do
    user = find_user(email)

    responses =
      1..2
      |> Enum.map(fn _ -> Task.async(fn -> resend_through_api(user) end) end)
      |> Task.await_many()

    Map.put(context, :api_responses, responses)
  end

  step "both requests are refused", context do
    for response <- context.api_responses do
      assert response["data"]["resendConfirmation"]["result"] == nil
      assert [_ | _] = response["data"]["resendConfirmation"]["errors"]
    end

    context
  end

  step "{string} asks for the confirmation email through GraphQL", %{args: [email]} = context do
    Map.put(context, :api_response, resend_through_api(find_user(email)))
  end

  step "the API refuses the resend with a retry time", context do
    response = context.api_response
    assert response["data"]["resendConfirmation"]["result"] == nil
    assert [%{"message" => message} | _] = response["data"]["resendConfirmation"]["errors"]
    assert [_, seconds] = Regex.run(~r/Try again in (\d+) seconds/, message)
    assert String.to_integer(seconds) in 1..60
    context
  end

  step "a confirmation email is sent to {string}", %{args: [email]} = context do
    assert_email_sent(fn sent ->
      assert [{_name, ^email}] = sent.to
      assert sent.subject == "Confirm your email address"
    end)

    context
  end

  step "no confirmation email is sent", context do
    refute_email_sent()
    context
  end

  step "I am told it was sent and to look in junk", %{session: session} = context do
    assert_has(session, "*", text: "Confirmation sent to")
    assert_has(session, "*", text: "look in junk")
    context
  end

  step "I am told when I can try again", %{session: session} = context do
    assert_has(session, "*", text: "Try again in")
    context
  end

  step "the retry guidance does not claim an email was sent", %{session: session} = context do
    refute_has(session, "[role=alert]", text: "We sent a link")
    assert_has(session, "[role=alert]", text: "requested")
    context
  end

  step "the API retry guidance does not claim an email was sent", context do
    [error | _] = context.api_response["data"]["resendConfirmation"]["errors"]
    refute error["message"] =~ "was sent"
    assert error["message"] =~ "requested"
    context
  end

  step "email cannot be sent right now", context do
    previous = Application.get_env(:huddlz, Huddlz.Mailer)
    Application.put_env(:huddlz, Huddlz.Mailer, adapter: Huddlz.Test.FailingMailAdapter)
    ExUnit.Callbacks.on_exit(fn -> Application.put_env(:huddlz, Huddlz.Mailer, previous) end)
    context
  end

  step "I am told nothing went out and to try again", %{session: session} = context do
    assert_has(session, "*", text: "Nothing went out")
    context
  end

  step "{string} has no confirmation links", %{args: [email]} = context do
    assert confirmation_links(find_user(email)) == []
    context
  end

  step "I follow the confirmation link from the email", %{session: session} = context do
    token = token_from_email()
    session = follow(session, token)
    Map.merge(context, %{conn: session, session: session})
  end

  step "I follow the earlier confirmation link", %{session: session} = context do
    session = follow(session, context.earlier_link)
    Map.merge(context, %{conn: session, session: session})
  end

  step "I have two unexpired confirmation links", context do
    {:ok, first} = Confirmation.mint(me(context))
    {:ok, second} = Confirmation.mint(me(context))
    Map.put(context, :links, [first, second])
  end

  step "I follow one of them", %{session: session, links: [first | _]} = context do
    session = follow(session, first)
    Map.merge(context, %{conn: session, session: session})
  end

  step "I open the other", %{session: session, links: [_, second]} = context do
    session = visit(session, "/confirm_new_user/#{second}")
    Map.merge(context, %{conn: session, session: session})
  end

  step "I am told the link no longer works", %{session: session} = context do
    assert_has(session, "*", text: "This confirmation link no longer works")
    context
  end

  step "{string} is confirmed now", %{args: [email]} = context do
    refute is_nil(find_user(email).confirmed_at)
    context
  end

  step "my confirmation link was sent four days ago", context do
    Map.put(context, :old_link, expired_link(me(context)))
  end

  step "I open it", %{session: session} = context do
    session = visit(session, "/confirm_new_user/#{context.old_link}")
    Map.merge(context, %{conn: session, session: session})
  end

  step "{string} has an unexpired confirmation link", %{args: [email]} = context do
    user = find_user(email)
    {:ok, token} = Confirmation.mint(user)
    Map.merge(context, %{old_link: token, old_link_user: user})
  end

  step "that account's address has since changed to {string}", %{args: [new_email]} = context do
    Ash.Seed.update!(context.old_link_user, %{email: new_email, confirmed_at: nil})

    context
  end

  step "the old link is opened", context do
    session = visit(build_conn(), "/confirm_new_user/#{context.old_link}")
    Map.merge(context, %{conn: session, session: session})
  end

  step "I submit the open confirmation page", %{session: session} = context do
    session = click_button(session, "Confirm my email")
    Map.merge(context, %{conn: session, session: session})
  end

  step "the confirmation failure explains that the link was for a previous address",
       %{session: session} = context do
    assert_has(session, "[role=alert]", text: "That confirmation link was for a previous address")
    context
  end

  step "I am told the link was for a previous address", %{session: session} = context do
    assert_has(session, "*", text: "This link was for a previous address")
    context
  end

  step "the account's address is still {string} and not confirmed", %{args: [email]} = context do
    user = User |> Ash.Query.filter(email == ^email) |> Ash.read_one!(authorize?: false)
    assert user
    assert is_nil(user.confirmed_at)
    context
  end

  defp resend!(user), do: Huddlz.Accounts.resend_confirmation!(user, actor: user)

  # The signed-in person as the database has them now, not as first generated.
  defp me(context), do: find_user(to_string(context.current_user.email))

  defp resend_through_api(user) do
    build_conn()
    |> authenticated_conn(user)
    |> gql_post(@resend_query, %{"id" => user.id})
    |> json_response(200)
  end

  defp follow(session, token) do
    session
    |> visit("/confirm_new_user/#{token}")
    |> click_button("Confirm my email")
  end

  defp token_from_email do
    assert_email_sent(fn sent ->
      [_, token] =
        Regex.run(~r{/confirm_new_user/([A-Za-z0-9._~-]+)}, sent.text_body || sent.html_body)

      Process.put(:confirmation_token, token)
      true
    end)

    Process.get(:confirmation_token)
  end

  # A link whose expiry claim is already in the past, stored like a real one.
  defp expired_link(user) do
    past = DateTime.utc_now() |> DateTime.add(-1, :day) |> DateTime.to_unix()

    {:ok, token, _claims} =
      Jwt.token_for_user(user, %{"act" => "confirm", "exp" => past}, token_lifetime: {3, :days})

    token
  end

  defp confirmation_links(user) do
    subject = AshAuthentication.user_to_subject(user)

    Token
    |> Ash.Query.filter(subject == ^subject and purpose == ^Confirmation.purpose())
    |> Ash.read!(authorize?: false)
  end

  defp find_user(email),
    do: User |> Ash.Query.filter(email == ^email) |> Ash.read_one!(authorize?: false)
end
