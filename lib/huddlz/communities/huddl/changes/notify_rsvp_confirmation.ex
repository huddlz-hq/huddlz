defmodule Huddlz.Communities.Huddl.Changes.NotifyRsvpConfirmation do
  @moduledoc """
  Enqueues E3 (rsvp_confirmation) email when a user RSVPs to a huddl.
  Sent to the actor (the rsvper) themselves, not to organizers — that's
  E1's job.

  No-ops on duplicate RSVPs: `Huddl.Changes.Rsvp` only sets
  `cs.context[:rsvp_created]` on the create path. If the attendee row
  already existed, the action still succeeds but no email fires.
  """

  use Ash.Resource.Change

  alias Huddlz.Notifications

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, &notify/2)
  end

  defp notify(cs, huddl) do
    with true <- cs.context[:rsvp_created] == true,
         %{id: _} = actor <- cs.context[:private][:actor] do
      Notifications.deliver_async(actor, :rsvp_confirmation, %{"huddl_id" => huddl.id})
      {:ok, huddl}
    else
      _ -> {:ok, huddl}
    end
  end
end
