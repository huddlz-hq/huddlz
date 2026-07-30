defmodule Huddlz.Communities.GroupInvitation.Changes.Accept do
  @moduledoc false

  use Ash.Resource.Change

  alias Huddlz.Communities

  @impl true
  def change(changeset, _opts, _context) do
    changeset
    |> Ash.Changeset.force_change_attribute(:status, :accepted)
    |> Ash.Changeset.force_change_attribute(:responded_at, DateTime.utc_now())
    |> Ash.Changeset.after_action(fn _changeset, invitation ->
      ensure_membership(invitation)
      {:ok, invitation}
    end)
  end

  defp ensure_membership(invitation) do
    case Communities.get_group_member(
           invitation.group_id,
           invitation.invitee_id,
           authorize?: false,
           not_found_error?: false
         ) do
      {:ok, nil} ->
        Communities.accept_invitation_membership!(
          invitation.group_id,
          invitation.invitee_id,
          invitation.role,
          authorize?: false
        )

      {:ok, %{role: :member} = membership} when invitation.role == :organizer ->
        Communities.set_member_role_from_invitation!(
          membership,
          :organizer,
          authorize?: false
        )

      {:ok, _membership} ->
        :ok
    end
  end
end
