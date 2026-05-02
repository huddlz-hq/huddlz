defmodule Huddlz.Communities.Group.Changes.NotifyArchived do
  @moduledoc """
  Enqueues B6 (group_archived) notifications when a group is destroyed.

  Captures member user_ids in `before_action` because the GroupMember
  rows cascade-delete with the group. The actor (the user destroying
  the group, typically the owner) is excluded from the recipients.
  Fans out emails in `after_action` once the destroy commits.
  """

  use Ash.Resource.Change

  require Ash.Query

  alias Huddlz.Accounts.User
  alias Huddlz.Communities.GroupMember
  alias Huddlz.Notifications

  @impl true
  def change(changeset, _opts, _context) do
    changeset
    |> Ash.Changeset.before_action(&capture_members/1)
    |> Ash.Changeset.after_action(&notify/2)
  end

  defp capture_members(cs) do
    user_ids =
      GroupMember
      |> Ash.Query.filter(group_id == ^cs.data.id)
      |> Ash.Query.select([:user_id])
      |> Ash.read!(authorize?: false)
      |> Enum.map(& &1.user_id)
      |> Enum.uniq()

    actor_id =
      case cs.context[:private][:actor] do
        %{id: id} -> id
        _ -> nil
      end

    recipients = Enum.reject(user_ids, &(&1 == actor_id))

    Ash.Changeset.put_context(cs, :group_archived_recipients, recipients)
  end

  defp notify(cs, group) do
    recipients = cs.context[:group_archived_recipients] || []

    payload = %{
      "group_id" => group.id,
      "group_name" => to_string(group.name)
    }

    for user_id <- recipients do
      case Ash.get(User, user_id, authorize?: false) do
        {:ok, user} -> Notifications.deliver(user, :group_archived, payload)
        _ -> :noop
      end
    end

    {:ok, group}
  end
end
