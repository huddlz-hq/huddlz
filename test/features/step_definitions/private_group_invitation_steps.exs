defmodule PrivateGroupInvitationSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import PhoenixTest

  alias Ecto.Adapters.SQL
  alias Huddlz.Communities

  step "I open the member workspace for {string}", %{args: [group_name]} = context do
    group = find_group(context, group_name)
    session = context[:session] || context[:conn]
    session = visit(session, "/organize/#{group.slug}/members")
    Map.merge(context, %{session: session, conn: session})
  end

  step "I submit a member invitation for {string}", %{args: [email]} = context do
    session = context[:session] || context[:conn]

    session =
      session
      |> fill_in("Email", with: email)
      |> select("Group role", option: "Member")
      |> click_button("Send invitation")

    Map.merge(context, %{session: session, conn: session})
  end

  step "I open my invitation to {string}", %{args: [group_name]} = context do
    group = find_group(context, group_name)

    invitation =
      Communities.list_my_group_invitations!(actor: context.current_user)
      |> Enum.find(&(&1.group_id == group.id))

    session = context[:session] || context[:conn]
    session = visit(session, "/invitations/#{invitation.id}")
    Map.merge(context, %{session: session, conn: session})
  end

  step "an invitation email should be sent to {string} for {string}",
       %{args: [email, group_name]} = context do
    Oban.drain_queue(queue: :notifications)
    body = assert_invitation_email_received(email, group_name)
    {:ok, Map.put(context, :invitation_email_body, body)}
  end

  step "I follow that invitation email while signed out", context do
    [{_, [{_, url}], _}] =
      context.invitation_email_body
      |> Floki.parse_fragment!()
      |> Floki.find("a")
      |> Enum.filter(fn {_, _, content} -> Floki.text(content) == "Review invitation" end)

    uri = URI.parse(url)
    path = uri.path <> if(uri.query, do: "?" <> uri.query, else: "")
    session = Phoenix.ConnTest.build_conn() |> visit(path)
    Map.merge(context, %{session: session, conn: session, invitation_path: path})
  end

  step "that invitation email includes notification preferences and unsubscribe links", context do
    assert context.invitation_email_body =~ "/profile/notifications"
    assert context.invitation_email_body =~ "/unsubscribe/"
    context
  end

  step "I reopen the invitation email", context do
    session = visit(context.session, context.invitation_path)
    Map.merge(context, %{session: session, conn: session})
  end

  step "I confirm the registration email sent to {string}", %{args: [email]} = context do
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
    session = context.session |> visit(URI.parse(url).path) |> click_button("Confirm your email")
    result = Oban.drain_queue(queue: :notifications)
    assert result.failure == 0, inspect(result)
    Map.merge(context, %{session: session, conn: session})
  end

  step "I start registration without an invitation link", context do
    session = Phoenix.ConnTest.build_conn() |> visit("/register")
    Map.merge(context, %{session: session, conn: session})
  end

  step "I complete registration as {string}", %{args: [email]} = context do
    session =
      context.session
      |> fill_in("Email", with: email)
      |> fill_in("Display Name", with: "New Maker")
      |> fill_in("Password", with: "secure-password-123")
      |> fill_in("Confirm Password", with: "secure-password-123")
      |> check(Huddlz.Legal.acceptance_text())
      |> click_button("Create account")

    Map.merge(context, %{session: session, conn: session})
  end

  step "the pending invitation to {string} for {string} has expired",
       %{args: [email, group_name]} = context do
    group = find_group(context, group_name)

    invitation =
      Communities.list_group_invitations!(group.id, actor: context.current_user)
      |> Enum.find(&(to_string(&1.email) == email and &1.status == :pending))

    # Time fixture: exercise the real browser and action expiration paths.
    SQL.query!(
      Huddlz.Repo,
      "UPDATE group_invitations SET expires_at = now() - interval '1 second' WHERE id = $1",
      [Ecto.UUID.dump!(invitation.id)]
    )

    context
  end

  step "{string} has working email and QR sharing controls", %{args: [name]} = context do
    group = find_group(context, name)
    path = "/groups/#{group.slug}"
    url = HuddlzWeb.Endpoint.url() <> path

    session =
      context.session
      |> assert_has("#share-group-modal-email[href^='mailto:']")
      |> assert_has("#share-group-modal-url[value='#{url}']")
      |> assert_has("#share-group-modal-open[phx-click*='share-group-modal']")
      |> assert_has("#share-group-modal .qr-frame svg")

    Map.merge(context, %{session: session, conn: session, shared_path: path})
  end

  step "I open that shared group link while signed out", context do
    {404, _headers, body} =
      Phoenix.ConnTest.assert_error_sent(404, fn ->
        Phoenix.ConnTest.dispatch(
          Phoenix.ConnTest.build_conn(),
          HuddlzWeb.Endpoint,
          :get,
          context.shared_path
        )
      end)

    Map.put(context, :error_body, body)
  end

  step "no invitation email should be sent to {string}", %{args: [email]} = context do
    Oban.drain_queue(queue: :notifications)
    refute_received {:email, %Swoosh.Email{subject: "Invitation to " <> _, to: [{"", ^email}]}}
    context
  end

  defp find_group(context, group_name) do
    Enum.find(context.groups, fn group ->
      to_string(group.name) == group_name
    end)
  end

  defp assert_invitation_email_received(email, group_name) do
    receive do
      {:email,
       %Swoosh.Email{
         subject: "Invitation to " <> ^group_name,
         to: [{"", ^email}],
         html_body: body
       }} ->
        assert body =~ "Review invitation"
        body

      {:email, _other} ->
        assert_invitation_email_received(email, group_name)
    after
      100 -> flunk("No invitation email received for #{email}")
    end
  end
end
