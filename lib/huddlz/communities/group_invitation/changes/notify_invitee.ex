defmodule Huddlz.Communities.GroupInvitation.Changes.NotifyInvitee do
  @moduledoc false

  use Ash.Resource.Change

  alias Huddlz.Notifications

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_transaction(changeset, fn
      _changeset, {:ok, invitation} ->
        invitation = Ash.load!(invitation, [:group, :invitee, :inviter], authorize?: false)

        Notifications.deliver(invitation.invitee, :group_invitation, %{
          "invitation_id" => invitation.id,
          "group_name" => to_string(invitation.group.name),
          "inviter_name" => invitation.inviter.display_name,
          "role" => Atom.to_string(invitation.role)
        })

        {:ok, invitation}

      _changeset, result ->
        result
    end)
  end
end
