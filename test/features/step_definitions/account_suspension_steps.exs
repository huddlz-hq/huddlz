defmodule AccountSuspensionSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import HuddlzWeb.ApiCase, only: [authenticated_conn: 2, gql_post: 3, api_key_conn: 2]
  import Phoenix.ConnTest, only: [build_conn: 0, dispatch: 4, json_response: 2]
  import PhoenixTest
  import Phoenix.ChannelTest

  require Ash.Query

  alias Huddlz.Accounts
  alias Huddlz.Accounts.User
  alias Huddlz.Communities
  alias Huddlz.Communities.{Group, Huddl, HuddlAttendee}
  alias Huddlz.Test.Helpers.Authentication

  @notice_subject "Your huddlz account has been suspended"
  @endpoint HuddlzWeb.Endpoint

  step "{string} has an open authenticated API connection", %{args: [email]} = context do
    user = find_user(email)
    {:ok, token, _} = AshAuthentication.Jwt.token_for_user(user, %{}, domain: Accounts)
    {:ok, socket} = connect(HuddlzWeb.GraphqlSocket, %{"token" => token})
    {:ok, _, socket} = subscribe_and_join(socket, "__absinthe__:control")
    ref = push(socket, "doc", %{"query" => "{ me { id } }"})
    assert_reply ref, :ok, %{data: %{"me" => %{"id" => id}}}
    assert id == user.id
    Map.put(context, :api_socket, socket)
  end

  step "the open API connection can no longer read the person's account", context do
    ref = push(context.api_socket, "doc", %{"query" => "{ me { id } }"})
    assert_reply ref, :ok, %{data: %{"me" => nil}}
    context
  end

  # ── suspension state ────────────────────────────────────────────────

  step "{string} is suspended", %{args: [email]} = context do
    assert %DateTime{} = find_user(email).suspended_at, "expected #{email} to be suspended"
    context
  end

  step "{string} is not suspended", %{args: [email]} = context do
    refute find_user(email).suspended_at, "expected #{email} not to be suspended"
    context
  end

  step "the suspension of {string} records {string} and the reason {string}",
       %{args: [email, admin_email, reason]} = context do
    user = find_user(email)
    assert %DateTime{} = user.suspended_at
    assert user.suspended_by_id == find_user(admin_email).id
    assert user.suspension_reason == reason
    context
  end

  step "{string} suspends {string} for {string}",
       %{args: [admin_email, email, reason]} = context do
    Accounts.suspend_user!(find_user(email), reason, actor: find_user(admin_email))
    context
  end

  step "{string} is not listed among the accounts", %{args: [name], session: session} = context do
    refute_has(session, "#accounts-roster", text: name)
    context
  end

  # ── API ─────────────────────────────────────────────────────────────

  step "I try to suspend {string} through the API", %{args: [email]} = context do
    target = find_user(email)

    response =
      gql_as(
        context.current_user,
        ~s|mutation { suspendAccount(id: "#{target.id}", input: {reason: "Spam"}) { result { id } errors { message } } }|
      )

    Map.put(context, :api_response, response)
  end

  step "I try to restore {string} through the API", %{args: [email]} = context do
    target = find_user(email)

    response =
      gql_as(
        context.current_user,
        ~s|mutation { restoreAccount(id: "#{target.id}") { result { id } errors { message } } }|
      )

    Map.put(context, :api_response, response)
  end

  step "the suspension is refused", context do
    assert get_in(context.api_response, ["data", "suspendAccount"]) == nil

    assert Enum.any?(
             context.api_response["errors"],
             &(&1["message"] =~ "Cannot query field \"suspendAccount\"")
           )

    context
  end

  step "the restoration is refused", context do
    assert get_in(context.api_response, ["data", "restoreAccount"]) == nil

    assert Enum.any?(
             context.api_response["errors"],
             &(&1["message"] =~ "Cannot query field \"restoreAccount\"")
           )

    context
  end

  step "the API members of {string} do not include {string}",
       %{args: [group_name, name]} = context do
    group = find_group(group_name)
    hidden = User |> Ash.Query.filter(display_name == ^name) |> Ash.read_one!(authorize?: false)

    ids =
      build_conn()
      |> authenticated_conn(context.current_user)
      |> dispatch(
        HuddlzWeb.Endpoint,
        :get,
        "/api/json/group_members/by_group?group_id=#{group.id}"
      )
      |> json_response(200)
      |> Map.fetch!("data")
      |> Enum.map(&get_in(&1, ["relationships", "user", "data", "id"]))

    assert ids != []
    refute hidden.id in ids
    context
  end

  step "the API people going to {string} do not include {string}",
       %{args: [title, name]} = context do
    refute name in people_going_through_api(context.current_user, find_huddl(title))
    context
  end

  step "the people going to {string} read through the API include {string} but not {string}",
       %{args: [title, shown, hidden]} = context do
    names = people_going_through_api(context.current_user, find_huddl(title))
    assert shown in names
    refute hidden in names
    context
  end

  # ── access ──────────────────────────────────────────────────────────

  step "{string} is signed in on another device", %{args: [email]} = context do
    user = find_user(email)

    device =
      build_conn()
      |> Authentication.login(user)
      |> visit("/agenda")
      |> assert_has("#sidebar-user", text: user.display_name)

    Map.put(context, :other_device, device)
  end

  step "the other device is signed out with {string}", %{args: [message]} = context do
    device =
      context.other_device
      |> visit("/agenda")
      |> assert_path("/account-suspended")
      |> assert_has("*", text: message)
      |> refute_has("a", text: "Sign out")

    Map.put(context, :other_device, device)
  end

  step "the other device is still signed out", context do
    device = context.other_device |> visit("/agenda") |> assert_path("/sign-in")
    Map.put(context, :other_device, device)
  end

  step "{string} has an API key", %{args: [email]} = context do
    Map.put(context, :api_key_conn, api_key_conn(build_conn(), find_user(email)))
  end

  step "the API key of {string} is rejected", %{args: [_email]} = context do
    conn = dispatch(context.api_key_conn, HuddlzWeb.Endpoint, :get, "/api/auth/me")
    assert conn.status == 401
    context
  end

  step "{string} cannot sign in with password {string}", %{args: [email, password]} = context do
    sign_in_attempt(email, password)
    |> assert_has("*", text: "This account is suspended")
    |> refute_has("a", text: "Sign out")

    context
  end

  step "{string} can sign in with password {string}", %{args: [email, password]} = context do
    user = find_user(email)

    sign_in_attempt(email, password)
    |> visit("/agenda")
    |> assert_has("#sidebar-user", text: user.display_name)

    context
  end

  step "the public group page for {string} is still open to browse", %{args: [name]} = context do
    group = find_group(name)
    build_conn() |> visit("/groups/#{group.slug}") |> assert_has("h1", text: name)
    context
  end

  step "{string} resets their password to {string}", %{args: [email, password]} = context do
    build_conn()
    |> visit("/reset")
    |> within("#reset-password-form", fn s ->
      s |> fill_in("Email", with: email) |> click_button("Send reset instructions")
    end)

    reset_link =
      Swoosh.TestAssertions.assert_email_sent(fn sent ->
        if sent.to == [{"", email}] and sent.subject == "Reset your password" do
          case Regex.run(~r{(https?://[^/]+/reset/[^\s"'<>]+)}, sent.html_body) do
            [_, url] -> url
            _ -> false
          end
        else
          false
        end
      end)

    session =
      build_conn()
      |> visit(reset_link)
      |> within("#reset-password-confirm-form", fn s ->
        s
        |> fill_in("New password", with: password)
        |> fill_in("Confirm new password", with: password)
        |> click_button("Reset password")
      end)

    Map.merge(context, %{session: session, conn: session})
  end

  step "{string} is still unconfirmed", %{args: [email]} = context do
    refute find_user(email).confirmed_at
    context
  end

  step "{string} asks for the confirmation email again", %{args: [email]} = context do
    user = find_user(email)
    {:ok, _user} = Accounts.resend_confirmation(user, actor: user)
    context
  end

  # ── spots ───────────────────────────────────────────────────────────

  step "{string} attended {string}", %{args: [email, title]} = context do
    HuddlAttendee
    |> Ash.Changeset.for_create(:rsvp, %{
      huddl_id: find_huddl(title).id,
      user_id: find_user(email).id
    })
    |> Ash.create!(authorize?: false)

    context
  end

  step "{string} is on the waitlist for {string}", %{args: [email, title]} = context do
    Communities.join_waitlist_huddl!(find_huddl(title), actor: find_user(email))
    context
  end

  step "{string} is confirmed for {string}", %{args: [email, title]} = context do
    assert %HuddlAttendee{waitlisted_at: nil} = attendance(email, title),
           "expected #{email} to hold a confirmed spot for #{title}"

    context
  end

  step "{string} is no longer attending {string}", %{args: [email, title]} = context do
    refute attendance(email, title), "expected #{email} to hold no spot for #{title}"
    context
  end

  # ── email ───────────────────────────────────────────────────────────

  step "an older RSVP notification names {string} to {string} for {string}",
       %{args: [name, email, title]} = context do
    Huddlz.Notifications.deliver(find_user(email), :rsvp_received, %{
      "rsvper_display_name" => name,
      "huddl_title" => title,
      "group_name" => "Portland Elixir",
      "group_slug" => "portland-elixir"
    })

    context
  end

  step "pending notification email is delivered", context do
    Oban.drain_queue(queue: :notifications)
    context
  end

  step "the RSVP email to {string} for {string} names {string} instead of {string}",
       %{args: [email, title, shown, hidden]} = context do
    subject = "#{shown} RSVPd to #{title}"
    assert_receive {:email, %Swoosh.Email{to: [{_, ^email}], subject: ^subject} = notice}, 1000
    assert notice.html_body =~ shown
    assert notice.text_body =~ shown
    refute notice.html_body =~ hidden
    refute notice.text_body =~ hidden
    context
  end

  step "a suspension notice is sent to {string} with the support address",
       %{args: [email]} = context do
    Oban.drain_queue(queue: :notifications)

    assert_receive {:email,
                    %Swoosh.Email{subject: @notice_subject, to: [{_, ^email}], text_body: body}},
                   1000

    assert body =~ "support@huddlz.com"
    Map.put(context, :notice_body, body)
  end

  step "the notice does not mention {string}", %{args: [text]} = context do
    refute context.notice_body =~ text
    context
  end

  step "{string} announces the huddl {string} in {string}",
       %{args: [email, title, group_name]} = context do
    host = find_user(email)
    group = find_group(group_name)
    generate(huddl(title: title, group_id: group.id, creator_id: host.id, actor: host))
    context
  end

  step "no huddl announcement is sent to {string}", %{args: [email]} = context do
    Oban.drain_queue(queue: :notifications)
    refute_receive {:email, %Swoosh.Email{subject: "New huddl in " <> _, to: [{_, ^email}]}}, 200
    context
  end

  step "a huddl announcement is sent to {string}", %{args: [email]} = context do
    Oban.drain_queue(queue: :notifications)
    assert_receive {:email, %Swoosh.Email{subject: "New huddl in " <> _, to: [{_, ^email}]}}, 1000
    context
  end

  # ── helpers ─────────────────────────────────────────────────────────

  defp sign_in_attempt(email, password) do
    build_conn()
    |> visit("/sign-in")
    |> within("#password-sign-in-form", fn s ->
      s
      |> fill_in("Email", with: email)
      |> fill_in("Password", with: password)
      |> click_button("Sign in")
    end)
  end

  defp people_going_through_api(viewer, huddl) do
    response =
      gql_as(viewer, ~s|{ huddlAttendees(huddlId: "#{huddl.id}") { displayName } }|)

    refute Map.has_key?(response, "errors"), inspect(response)
    Enum.map(response["data"]["huddlAttendees"], & &1["displayName"])
  end

  defp gql_as(user, query) do
    build_conn()
    |> authenticated_conn(user)
    |> gql_post(query, %{})
    |> json_response(200)
  end

  defp attendance(email, title) do
    HuddlAttendee
    |> Ash.Query.filter(user_id == ^find_user(email).id and huddl_id == ^find_huddl(title).id)
    |> Ash.read_one!(authorize?: false)
  end

  defp find_user(email) do
    User |> Ash.Query.filter(email == ^email) |> Ash.read_one!(authorize?: false)
  end

  defp find_group(name) do
    Group |> Ash.Query.filter(name == ^name) |> Ash.read_one!(authorize?: false)
  end

  defp find_huddl(title) do
    Huddl
    |> Ash.Query.for_read(:read_for_group_lifecycle)
    |> Ash.Query.filter(title == ^title)
    |> Ash.read_one!(authorize?: false)
  end
end
