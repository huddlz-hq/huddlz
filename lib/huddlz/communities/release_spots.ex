defmodule Huddlz.Communities.ReleaseSpots do
  @moduledoc """
  Gives back a person's upcoming RSVP and waitlist spots, as a suspension
  requires. History stays: each released row is destroyed through the
  ordinary `:cancel_rsvp` action, so its version records who acted and
  when. A confirmed seat that opens is offered to the oldest waitlisted
  person under the usual capacity rules, and the promoted person is told.

  Runs inside the caller's transaction, one huddl at a time under the same
  row lock `:rsvp` and `:cancel_rsvp` take, so concurrent RSVP attempts
  cannot overbook the freed seat.
  """

  alias Huddlz.Accounts.User
  alias Huddlz.Communities.Huddl
  alias Huddlz.Communities.Huddl.Changes.LockedHuddl
  alias Huddlz.Communities.HuddlAttendee
  alias Huddlz.Notifications

  require Ash.Query

  @doc """
  Release every upcoming spot held by `user`. `opts` are the nested action
  options (actor, audit metadata) the released rows are recorded with.
  Returns the released rows.
  """
  @spec release_upcoming(User.t(), keyword()) :: [HuddlAttendee.t()]
  def release_upcoming(%User{id: user_id}, opts) do
    HuddlAttendee
    |> Ash.Query.filter(user_id == ^user_id and huddl.ends_at > now())
    |> Ash.read!(authorize?: false)
    |> Enum.map(&release(&1, opts))
  end

  defp release(%HuddlAttendee{} = attendee, opts) do
    case LockedHuddl.fetch(attendee.huddl_id) do
      {:ok, %Huddl{}} ->
        attendee
        |> Ash.Changeset.for_destroy(:cancel_rsvp, %{}, opts)
        |> Ash.destroy!(authorize?: false)

        if is_nil(attendee.waitlisted_at), do: fill_seat(attendee.huddl_id, opts)

      _gone ->
        :ok
    end

    attendee
  end

  # Mirrors `Huddl.Changes.PromoteFromWaitlist`: re-read under the lock, and
  # only promote when the count says a seat is open.
  defp fill_seat(huddl_id, opts) do
    with {:ok, %Huddl{at_capacity: false} = huddl} <- LockedHuddl.fetch(huddl_id, :at_capacity),
         %HuddlAttendee{} = next <- oldest_waiting(huddl_id) do
      next
      |> Ash.Changeset.for_update(:promote_from_waitlist, %{}, put_automatic(opts))
      |> Ash.update!(authorize?: false)

      notify_promoted(next.user_id, huddl)
    else
      _no_seat_or_nobody_waiting -> :ok
    end
  end

  defp oldest_waiting(huddl_id) do
    HuddlAttendee
    |> Ash.Query.filter(
      huddl_id == ^huddl_id and not is_nil(waitlisted_at) and is_nil(user.suspended_at)
    )
    |> Ash.Query.sort(waitlisted_at: :asc)
    |> Ash.Query.limit(1)
    |> Ash.read_one!(authorize?: false)
  end

  defp put_automatic(opts) do
    Keyword.update(opts, :context, %{paper_trail_metadata: %{automatic?: true}}, fn context ->
      Map.update(
        context,
        :paper_trail_metadata,
        %{automatic?: true},
        &Map.put(&1, :automatic?, true)
      )
    end)
  end

  defp notify_promoted(user_id, huddl) do
    huddl = Ash.load!(huddl, [:group], authorize?: false)

    case Ash.get(User, user_id, authorize?: false) do
      {:ok, user} ->
        Notifications.deliver(user, :waitlist_promoted, %{
          "huddl_id" => huddl.id,
          "huddl_title" => to_string(huddl.title),
          "group_name" => to_string(huddl.group.name),
          "group_slug" => to_string(huddl.group.slug),
          "starts_at_iso" => DateTime.to_iso8601(huddl.starts_at),
          "time_zone" => huddl.time_zone
        })

      _ ->
        :noop
    end
  end
end
