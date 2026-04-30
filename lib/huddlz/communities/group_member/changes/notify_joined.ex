defmodule Huddlz.Communities.GroupMember.Changes.NotifyJoined do
  @moduledoc """
  Enqueues B1 (group_member_joined) notifications when a user joins a
  public group via :join_group. Recipients are the group's owner and
  organizers, deduplicated and with the actor (the joining user)
  excluded.
  """

  use Ash.Resource.Change

  require Ash.Query

  alias Huddlz.Accounts.User
  alias Huddlz.Communities.Group
  alias Huddlz.Communities.GroupMember
  alias Huddlz.Notifications

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _cs, member ->
      deliver(member)
      {:ok, member}
    end)
  end

  defp deliver(%GroupMember{group_id: group_id, user_id: joiner_id}) do
    with {:ok, group} <- Ash.get(Group, group_id, authorize?: false),
         {:ok, joiner} <- Ash.get(User, joiner_id, authorize?: false) do
      payload = %{
        "group_id" => group.id,
        "group_name" => to_string(group.name),
        "group_slug" => group.slug,
        "joiner_display_name" => joiner.display_name
      }

      group_id
      |> recipient_user_ids(joiner_id)
      |> Enum.each(&deliver_to(&1, payload))
    end
  end

  defp deliver_to(user_id, payload) do
    case Ash.get(User, user_id, authorize?: false) do
      {:ok, recipient} -> Notifications.deliver_async(recipient, :group_member_joined, payload)
      _ -> :noop
    end
  end

  defp recipient_user_ids(group_id, joiner_id) do
    GroupMember
    |> Ash.Query.filter(group_id == ^group_id and role in [:owner, :organizer])
    |> Ash.Query.select([:user_id])
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.user_id)
    |> Enum.uniq()
    |> Enum.reject(&(&1 == joiner_id))
  end
end
