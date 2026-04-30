defmodule Huddlz.Communities.GroupMember.Changes.NotifyAdded do
  @moduledoc """
  Enqueues B2 (group_member_added) notifications when a user is added
  to a *private* group via :add_member. Per spec, additions to public
  groups do not get a "you were added" email — joins are user-driven
  there. The actor (typically the owner/organizer doing the adding) is
  excluded if for any reason they would otherwise be the recipient.
  """

  use Ash.Resource.Change

  alias Huddlz.Accounts.User
  alias Huddlz.Communities.Group
  alias Huddlz.Notifications

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn cs, member ->
      actor_id = actor_id(cs)
      maybe_deliver(member, actor_id)
      {:ok, member}
    end)
  end

  defp maybe_deliver(member, actor_id) do
    cond do
      member.user_id == actor_id ->
        :noop

      member.role == :owner ->
        # :owner additions are internal flows (Group.:create_group's
        # self-add and Group.:transfer_ownership). Those have their own
        # notifications (B7) — don't double up with a B2 "you were added".
        :noop

      true ->
        with {:ok, group} <- Ash.get(Group, member.group_id, authorize?: false),
             true <- group.is_public == false,
             {:ok, recipient} <- Ash.get(User, member.user_id, authorize?: false) do
          Notifications.deliver_async(recipient, :group_member_added, %{
            "group_id" => group.id,
            "group_name" => to_string(group.name),
            "group_slug" => group.slug
          })
        else
          _ -> :noop
        end
    end
  end

  defp actor_id(%Ash.Changeset{} = cs) do
    case cs.context[:private][:actor] do
      %{id: id} -> id
      _ -> nil
    end
  end
end
