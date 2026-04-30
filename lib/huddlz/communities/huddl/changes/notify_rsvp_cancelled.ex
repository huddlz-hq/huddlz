defmodule Huddlz.Communities.Huddl.Changes.NotifyRsvpCancelled do
  @moduledoc """
  Enqueues E2 (rsvp_cancelled) emails when a user cancels their RSVP
  to a huddl. Sent to the group's owner and organizers, deduplicated,
  with the actor (the rsvper) excluded.

  No-ops when there was no actual RSVP to cancel: `Huddl.Changes.CancelRsvp`
  only sets `cs.context[:rsvp_cancelled]` on the destroy path. If no
  attendee row existed, the action still succeeds but no email fires.
  """

  use Ash.Resource.Change

  require Ash.Query

  alias Huddlz.Accounts.User
  alias Huddlz.Communities.GroupMember
  alias Huddlz.Communities.Huddl.Changes.RecipientHelpers
  alias Huddlz.Notifications

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, &notify/2)
  end

  defp notify(cs, huddl) do
    cond do
      cs.context[:rsvp_cancelled] != true ->
        {:ok, huddl}

      is_nil(RecipientHelpers.actor_id(cs)) ->
        {:ok, huddl}

      true ->
        deliver(huddl, RecipientHelpers.actor_id(cs))
        {:ok, huddl}
    end
  end

  defp deliver(huddl, actor_id) do
    huddl = Ash.load!(huddl, [:group], authorize?: false)

    payload = %{
      "huddl_id" => huddl.id,
      "huddl_title" => to_string(huddl.title),
      "starts_at_iso" => DateTime.to_iso8601(huddl.starts_at),
      "group_name" => to_string(huddl.group.name),
      "group_slug" => to_string(huddl.group.slug),
      "rsvper_display_name" => rsvper_display_name(actor_id)
    }

    huddl.group_id
    |> recipient_user_ids(actor_id)
    |> Enum.each(&deliver_to(&1, payload))
  end

  defp deliver_to(user_id, payload) do
    case Ash.get(User, user_id, authorize?: false) do
      {:ok, recipient} -> Notifications.deliver_async(recipient, :rsvp_cancelled, payload)
      _ -> :noop
    end
  end

  defp recipient_user_ids(group_id, actor_id) do
    GroupMember
    |> Ash.Query.filter(group_id == ^group_id and role in [:owner, :organizer])
    |> Ash.Query.select([:user_id])
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.user_id)
    |> Enum.uniq()
    |> Enum.reject(&(&1 == actor_id))
  end

  defp rsvper_display_name(actor_id) do
    case Ash.get(User, actor_id, authorize?: false) do
      {:ok, user} -> to_string(user.display_name)
      _ -> "Someone"
    end
  end
end
