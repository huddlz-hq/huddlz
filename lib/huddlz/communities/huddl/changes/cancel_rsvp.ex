defmodule Huddlz.Communities.Huddl.Changes.CancelRsvp do
  @moduledoc """
  Handles RSVP cancellation and waitlist withdrawal: destroys the
  attendee record if one exists, regardless of whether it represents an
  active RSVP or a waitlist entry.

  Sets `:rsvp_cancelled` context only when an active attendee row was
  destroyed (a real freed seat) so that downstream changes
  (`PromoteFromWaitlist`, `NotifyRsvpCancelled`) can no-op for waitlist
  withdrawals. Sets `:waitlist_left` when a waitlist row was destroyed
  so the LiveView flash message can distinguish the two cases.
  """
  use Ash.Resource.Change

  require Ash.Query

  def change(changeset, _opts, %{actor: %{id: user_id}}) when not is_nil(user_id) do
    huddl_id = changeset.data.id

    existing =
      Huddlz.Communities.HuddlAttendee
      |> Ash.Query.for_read(:check_rsvp, %{huddl_id: huddl_id}, actor: %{id: user_id})
      |> Ash.read_one(authorize?: false)

    case existing do
      {:ok, nil} ->
        changeset

      {:ok, %{waitlisted_at: nil} = attendee} ->
        Ash.destroy!(attendee, authorize?: false)
        # Load-bearing: NotifyRsvpCancelled and PromoteFromWaitlist skip
        # when this flag is absent — pure waitlist withdrawals don't
        # free a seat or warrant an organizer email.
        Ash.Changeset.put_context(changeset, :rsvp_cancelled, true)

      {:ok, %{waitlisted_at: %DateTime{}} = attendee} ->
        Ash.destroy!(attendee, authorize?: false)
        Ash.Changeset.put_context(changeset, :waitlist_left, true)

      {:error, error} ->
        Ash.Changeset.add_error(changeset, error)
    end
  end

  def change(changeset, _opts, _context) do
    Ash.Changeset.add_error(changeset, "An actor is required to cancel an RSVP")
  end
end
