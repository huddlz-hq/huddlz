defmodule Huddlz.Communities.Huddl.Changes.PromoteFromWaitlist do
  @moduledoc """
  After an RSVP is cancelled, promote the oldest waitlist entry (if any)
  to an active attendee. Triggered by `:cancel_rsvp` when a real seat
  was freed.

  The after-action notifier uses the promoted user IDs recorded here.
  """

  use Ash.Resource.Change

  alias Huddlz.Communities.Huddl
  alias Huddlz.Communities.Huddl.Changes.LockedHuddl
  alias Huddlz.Communities.WaitlistPromotion

  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, &maybe_promote/1)
  end

  defp maybe_promote(%{context: %{rsvp_cancelled: true}} = cs) do
    case LockedHuddl.fetch(cs.data.id, :at_capacity) do
      {:ok, %Huddl{} = huddl} ->
        user_ids = WaitlistPromotion.fill_released_seat(huddl, Huddlz.Audit.nested_opts(cs))
        Ash.Changeset.put_context(cs, :promoted_user_ids, user_ids)

      error ->
        LockedHuddl.add_read_error(cs, error)
    end
  end

  defp maybe_promote(cs), do: cs
end
