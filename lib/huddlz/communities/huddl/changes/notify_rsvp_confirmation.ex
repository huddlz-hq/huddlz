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
    case Ash.get(User, actor_id, authorize?: false) do
      {:ok, user} ->
        Notifications.deliver_async(user, :rsvp_confirmation, %{"huddl_id" => huddl.id})

      _ ->
        :noop
    end
  end
end
