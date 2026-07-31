defmodule Huddlz.Communities.Huddl.Changes.NotifyNewInGroup do
  @moduledoc """
  Enqueues C1 (huddl_new) notifications when a new huddl is created
  in a group. Sent to every group member except the actor (the user
  who created the huddl).

  Skipped when the create runs without an actor — that path is
  reserved for system-driven creations (e.g. `RecurrenceHelper`
  generating subsequent instances of a recurring series). Group
  members shouldn't get a notification for a draft or for
  system-generated recurring instances until an organizer explicitly
  publishes that huddl.

  Recipient resolution happens in `after_action` once the huddl row
  exists, so the new huddl's group is reachable.
  """

  use Ash.Resource.Change

  require Ash.Query

  alias Huddlz.Communities.GroupMember
  alias Huddlz.Communities.Huddl.Changes.RecipientHelpers

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, &notify/2)
  end

  defp notify(cs, huddl) do
    with true <- notification_due?(cs, huddl),
         actor_id when not is_nil(actor_id) <- RecipientHelpers.actor_id(cs) do
      notify_with_actor(cs, huddl, actor_id)
    else
      _ -> {:ok, huddl}
    end
  end

  defp notification_due?(%{action_type: :create}, %{lifecycle_state: :published}), do: true

  defp notification_due?(cs, _huddl) do
    cs.context[:lifecycle_transition] == :published
  end

  defp notify_with_actor(_cs, huddl, actor_id) do
    huddl = Ash.load!(huddl, [:group], authorize?: false)

    user_ids =
      GroupMember
      |> Ash.Query.filter(group_id == ^huddl.group_id)
      |> Ash.Query.select([:user_id])
      |> Ash.read!(authorize?: false)
      |> Enum.map(& &1.user_id)
      |> Enum.uniq()
      |> Enum.reject(&(&1 == actor_id))

    payload = %{
      "huddl_id" => huddl.id,
      "huddl_title" => to_string(huddl.title),
      "starts_at_iso" => DateTime.to_iso8601(huddl.starts_at),
      "group_name" => to_string(huddl.group.name),
      "group_slug" => to_string(huddl.group.slug)
    }

    RecipientHelpers.deliver_each(user_ids, :huddl_new, payload)

    {:ok, huddl}
  end
end
