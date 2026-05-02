defmodule Huddlz.Communities.Huddl.Changes.PromoteFromWaitlist do
  @moduledoc """
  After an RSVP is cancelled, promote the oldest waitlist entry (if any)
  to an active attendee. Triggered by `:cancel_rsvp` when a real seat
  was freed.

  Promotion clears `waitlisted_at` on the waitlist row rather than
  creating a new attendee row, which keeps the unique (huddl_id,
  user_id) constraint coherent across promotion.

  Sets `:promoted_user_id` in the changeset context so that
  `NotifyWaitlistPromoted` can deliver the heads-up email after the
  outer transaction commits.
  """

  use Ash.Resource.Change

  alias Huddlz.Communities.HuddlAttendee

  require Ash.Query

  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, &maybe_promote/1)
  end

  defp maybe_promote(cs) do
    if cs.context[:rsvp_cancelled] == true do
      do_promote(cs)
    else
      cs
    end
  end

  defp do_promote(cs) do
    case fetch_oldest_waitlist_entry(cs.data.id) do
      nil ->
        cs

      attendee ->
        attendee
        |> Ash.Changeset.for_update(:promote_from_waitlist)
        |> Ash.update!(authorize?: false)

        Ash.Changeset.put_context(cs, :promoted_user_id, attendee.user_id)
    end
  end

  defp fetch_oldest_waitlist_entry(huddl_id) do
    HuddlAttendee
    |> Ash.Query.filter(huddl_id == ^huddl_id and not is_nil(waitlisted_at))
    |> Ash.Query.sort(waitlisted_at: :asc)
    |> Ash.Query.limit(1)
    |> Ash.read_one!(authorize?: false)
  end
end
