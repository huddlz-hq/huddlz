defmodule PrivateGroupInvitationSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import PhoenixTest

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
      |> fill_in("Registered email", with: email)
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
    assert_invitation_email_received(email, group_name)
    {:ok, context}
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

      {:email, _other} ->
        assert_invitation_email_received(email, group_name)
    after
      100 -> flunk("No invitation email received for #{email}")
    end
  end
end
