defmodule Huddlz.Communities.Huddl.Changes.NotifyRsvpReceived do
  @moduledoc """
  Enqueues E1 (rsvp_received) emails when a user RSVPs to a huddl.
  Sent to the group's owner and organizers, deduplicated, with the
  actor (the rsvper) excluded.

  No-ops on duplicate RSVPs: `Huddl.Changes.Rsvp` only sets
  `cs.context[:rsvp_created]` on the create path. If the attendee row
  already existed, the action still succeeds but no email fires.
  """

  use Ash.Resource.Change

  alias Huddlz.Accounts.User
  alias Huddlz.Communities.Huddl.Changes.RecipientHelpers
  alias Huddlz.Notifications

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, &notify/2)
  end

  defp notify(cs, huddl) do
    cond do
      cs.context[:rsvp_created] != true ->
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
      "rsvper_display_name" => RecipientHelpers.user_display_name(actor_id, "Someone")
    }

    huddl.group_id
    |> RecipientHelpers.group_organizer_user_ids(exclude: actor_id)
    |> Enum.each(&deliver_to(&1, payload))
  end

  defp deliver_to(user_id, payload) do
    case Ash.get(User, user_id, authorize?: false) do
      {:ok, recipient} -> Notifications.deliver_async(recipient, :rsvp_received, payload)
      _ -> :noop
    end
  end
end
