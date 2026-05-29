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

  Concurrency: runs inside a `before_action` hook and locks the huddl row
  `FOR UPDATE` before freeing the seat. `:rsvp` and `:join_waitlist` take
  the same lock, so a cancellation (and the waitlist promotion that follows
  it) serializes with concurrent RSVP attempts and cannot overbook. The
  destroy must happen inside the action transaction — doing it in the
  `change/3` body would commit the freed seat before the lock is held.
  """
  use Ash.Resource.Change

  alias Huddlz.Communities.{Huddl, HuddlAttendee}

  require Ash.Query

  def change(changeset, _opts, %{actor: %{id: user_id}}) when not is_nil(user_id) do
    Ash.Changeset.before_action(changeset, &cancel(&1, user_id))
  end

  def change(changeset, _opts, _context) do
    Ash.Changeset.add_error(changeset, "An actor is required to cancel an RSVP")
  end

  defp cancel(cs, user_id) do
    # Lock the huddl row up front so the freed seat and any waitlist
    # promotion serialize against concurrent RSVP/waitlist transactions.
    lock_huddl!(cs.data.id)

    case fetch_existing(cs.data.id, user_id) do
      {:ok, nil} ->
        cs

      {:ok, %{waitlisted_at: nil} = attendee} ->
        Ash.destroy!(attendee, authorize?: false)
        # Load-bearing: NotifyRsvpCancelled and PromoteFromWaitlist skip
        # when this flag is absent — pure waitlist withdrawals don't
        # free a seat or warrant an organizer email.
        Ash.Changeset.put_context(cs, :rsvp_cancelled, true)

      {:ok, %{waitlisted_at: %DateTime{}} = attendee} ->
        Ash.destroy!(attendee, authorize?: false)
        Ash.Changeset.put_context(cs, :waitlist_left, true)

      {:error, error} ->
        Ash.Changeset.add_error(cs, error)
    end
  end

  defp lock_huddl!(huddl_id) do
    Huddl
    |> Ash.Query.filter(id == ^huddl_id)
    |> Ash.Query.lock("FOR UPDATE")
    |> Ash.read_one!(authorize?: false)
  end

  defp fetch_existing(huddl_id, user_id) do
    HuddlAttendee
    |> Ash.Query.for_read(:check_rsvp, %{huddl_id: huddl_id}, actor: %{id: user_id})
    |> Ash.read_one(authorize?: false)
  end
end
