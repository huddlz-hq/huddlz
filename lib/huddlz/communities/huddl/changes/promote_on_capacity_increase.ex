defmodule Huddlz.Communities.Huddl.Changes.PromoteOnCapacityIncrease do
  @moduledoc """
  When organizers raise (or lift) `max_attendees`, promote enough
  waitlisted users to fill the newly available seats. Runs after the
  update so the new capacity is visible to the count math.

  Records `[user_id]` in `cs.context[:promoted_user_ids]` so
  `NotifyMeaningfulUpdate` (or a dedicated change) can fan out
  promotion emails.
  """

  use Ash.Resource.Change

  alias Huddlz.Communities.HuddlAttendee
  alias Huddlz.Notifications

  require Ash.Query

  def change(changeset, _opts, _context) do
    if Ash.Changeset.changing_attribute?(changeset, :max_attendees) do
      Ash.Changeset.after_action(changeset, &promote_then_notify/2)
    else
      changeset
    end
  end

  defp promote_then_notify(_cs, huddl) do
    huddl = Ash.load!(huddl, [:rsvp_count, :group], authorize?: false)

    seats_open = seats_open(huddl)

    promoted_ids =
      if seats_open > 0 do
        promote_n(huddl.id, seats_open)
      else
        []
      end

    Enum.each(promoted_ids, fn user_id ->
      payload = %{
        "huddl_id" => huddl.id,
        "huddl_title" => to_string(huddl.title),
        "group_name" => to_string(huddl.group.name),
        "group_slug" => to_string(huddl.group.slug)
      }

      with {:ok, user} <- Ash.get(Huddlz.Accounts.User, user_id, authorize?: false) do
        Notifications.deliver_async(user, :waitlist_promoted, payload)
      end
    end)

    {:ok, huddl}
  end

  defp seats_open(%{max_attendees: nil} = huddl), do: count_waitlist(huddl.id)
  defp seats_open(%{max_attendees: max, rsvp_count: count}), do: max(max - count, 0)

  defp count_waitlist(huddl_id) do
    HuddlAttendee
    |> Ash.Query.filter(huddl_id == ^huddl_id and not is_nil(waitlisted_at))
    |> Ash.count!(authorize?: false)
  end

  defp promote_n(huddl_id, n) do
    HuddlAttendee
    |> Ash.Query.filter(huddl_id == ^huddl_id and not is_nil(waitlisted_at))
    |> Ash.Query.sort(waitlisted_at: :asc)
    |> Ash.Query.limit(n)
    |> Ash.read!(authorize?: false)
    |> Enum.map(fn entry ->
      entry
      |> Ash.Changeset.for_update(:promote_from_waitlist)
      |> Ash.update!(authorize?: false)

      entry.user_id
    end)
  end
end
