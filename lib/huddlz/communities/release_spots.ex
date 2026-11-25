defmodule Huddlz.Communities.ReleaseSpots do
  @moduledoc """
  Releases a person's upcoming RSVP and waitlist spots on suspension or
  account deletion. The ordinary `:cancel_rsvp` action records who released
  each spot and when. When a confirmed seat opens, the next person on the
  waitlist gets the seat and a notification.

  Runs inside the caller's transaction, one huddl at a time under the same
  row lock `:rsvp` and `:cancel_rsvp` take, so concurrent RSVP attempts
  cannot overbook the freed seat.
  """

  alias Huddlz.Accounts.User
  alias Huddlz.Communities
  alias Huddlz.Communities.Huddl
  alias Huddlz.Communities.Huddl.Changes.LockedHuddl
  alias Huddlz.Communities.HuddlAttendee
  alias Huddlz.Communities.WaitlistPromotion

  require Ash.Query

  @doc """
  Release every upcoming spot held by `user`. `opts` are the nested action
  options (actor, audit metadata) the released rows are recorded with.
  Returns the released rows.
  """
  @spec release_upcoming(User.t(), keyword()) :: [HuddlAttendee.t()]
  def release_upcoming(%User{id: user_id} = user, opts) do
    HuddlAttendee
    |> Ash.Query.filter(user_id == ^user_id and huddl.ends_at > now())
    |> Ash.Query.select(:huddl_id)
    |> Ash.read!(authorize?: false)
    |> Enum.flat_map(&release_for_huddl(&1.huddl_id, user, opts))
  end

  defp release_for_huddl(huddl_id, user, opts) do
    case LockedHuddl.fetch(huddl_id) do
      {:ok, %Huddl{}} ->
        # A cancellation may have promoted or removed this person's spot
        # since enumeration. Decide what to release under the huddl lock.
        huddl_id
        |> Communities.check_user_rsvp!(actor: user, authorize?: false)
        |> Enum.map(&release(&1, opts))

      _gone ->
        []
    end
  end

  defp release(attendee, opts) do
    attendee
    |> Ash.Changeset.for_destroy(:cancel_rsvp, %{}, opts)
    |> Ash.destroy!(authorize?: false)

    if is_nil(attendee.waitlisted_at), do: fill_seat(attendee.huddl_id, opts)
    attendee
  end

  defp fill_seat(huddl_id, opts) do
    with {:ok, %Huddl{} = huddl} <- LockedHuddl.fetch(huddl_id, :at_capacity) do
      user_ids = WaitlistPromotion.fill_released_seat(huddl, opts)
      WaitlistPromotion.notify(huddl, user_ids)
    end
  end
end
