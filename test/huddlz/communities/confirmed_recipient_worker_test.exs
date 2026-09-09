defmodule Huddlz.Communities.ConfirmedRecipientWorkerTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Communities
  alias Huddlz.Communities.GroupInvitation.ConfirmedRecipientWorker
  alias Huddlz.Notifications

  setup do
    owner = generate(user())
    group = generate(group(actor: owner, is_public: false))

    invitation =
      Communities.invite_to_group_by_email!(group.id, "confirmed@example.com", :member,
        actor: owner
      )

    recipient = generate(user(email: "confirmed@example.com"))
    job = %Oban.Job{args: %{"user_id" => recipient.id, "email" => "confirmed@example.com"}}
    %{owner: owner, invitation: invitation, recipient: recipient, job: job}
  end

  test "confirmation retries expose one invitation and one notification", context do
    assert :ok = ConfirmedRecipientWorker.perform(context.job)
    assert :ok = ConfirmedRecipientWorker.perform(context.job)

    assert [invitation] = Communities.group_invitations_for_actor!(actor: context.recipient)
    assert invitation.id == context.invitation.id
    assert invitation.status == :pending
    assert [_notification] = Notifications.list_for_user!(actor: context.recipient)
  end

  test "confirmation does not revive a revoked invitation", context do
    Communities.revoke_group_invitation!(context.invitation, actor: context.owner)

    assert :ok = ConfirmedRecipientWorker.perform(context.job)
    assert [] = Communities.group_invitations_for_actor!(actor: context.recipient)
    assert [] = Notifications.list_for_user!(actor: context.recipient)
  end

  test "confirmation proof for another email cannot claim the recipient's invitation", context do
    job = %{context.job | args: %{context.job.args | "email" => "previous@example.com"}}

    assert :ok = ConfirmedRecipientWorker.perform(job)
    assert [] = Communities.group_invitations_for_actor!(actor: context.recipient)
    assert [] = Notifications.list_for_user!(actor: context.recipient)
  end
end
