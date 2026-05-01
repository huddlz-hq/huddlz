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

  alias Huddlz.Communities.Huddl.Changes.RecipientHelpers

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, &notify/2)
  end

  defp notify(cs, huddl) do
    with true <- cs.context[:rsvp_created] == true,
         %{id: _} = actor <- cs.context[:private][:actor] do
      deliver(huddl, actor)
      {:ok, huddl}
    else
      _ -> {:ok, huddl}
    end
  end

  defp deliver(huddl, actor) do
    huddl = Ash.load!(huddl, [:group], authorize?: false)

    payload = %{
      "huddl_id" => huddl.id,
      "huddl_title" => to_string(huddl.title),
      "group_name" => to_string(huddl.group.name),
      "group_slug" => to_string(huddl.group.slug),
      "rsvper_display_name" => to_string(actor.display_name)
    }

    huddl.group_id
    |> RecipientHelpers.group_organizer_user_ids(exclude: actor.id)
    |> RecipientHelpers.deliver_each(:rsvp_received, payload)
  end
end
