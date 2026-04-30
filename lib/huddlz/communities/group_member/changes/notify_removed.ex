defmodule Huddlz.Communities.GroupMember.Changes.NotifyRemoved do
  @moduledoc """
  Enqueues the B3 notification (group_member_removed) for the user being
  removed from a group, after the destroy successfully commits. Skips
  the notification if the actor is the user being removed (e.g. they
  left themselves via :remove_member, which the spec treats as B5 → no
  email).
  """

  use Ash.Resource.Change

  require Ash.Query

  alias Huddlz.Communities.Group
  alias Huddlz.Notifications

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn cs, member ->
      actor_id = actor_id(cs)

      if member.user_id != actor_id do
        deliver(member)
      end

      {:ok, member}
    end)
  end

  defp deliver(member) do
    with {:ok, user} <- Ash.get(Huddlz.Accounts.User, member.user_id, authorize?: false),
         {:ok, group} <- Ash.get(Group, member.group_id, authorize?: false) do
      Notifications.deliver_async(user, :group_member_removed, %{
        "group_id" => group.id,
        "group_name" => to_string(group.name)
      })
    end
  end

  defp actor_id(%Ash.Changeset{} = cs) do
    case cs.context[:private][:actor] do
      %{id: id} -> id
      _ -> nil
    end
  end
end
