defmodule Huddlz.Communities.Huddl.Changes.SuggestJoining do
  @moduledoc """
  Stamps `join_suggestions_sent_at` and raises `:group_join_suggestion` for
  each drop-in who held an RSVP when the huddl completed (ADR-0011).

  Invoked by the AshOban-scheduled `:suggest_joining` action about a day
  after completion. Eligibility is decided here, at send time, not when the
  huddl completed: the person must still be a drop-in at the group, which
  the `:dropped_in` relationship answers (public group, not joined, no
  "Not now", never left or removed). The waitlist never counts, because
  only RSVPs are read.

  "Once per group" is kept by `DropInReminder.:mark_emailed`, an upsert
  that wins only for a row never emailed before. Whoever loses that race,
  or was emailed after an earlier huddl, is skipped.
  """

  use Ash.Resource.Change

  require Ash.Query

  alias Huddlz.Accounts.User
  alias Huddlz.Communities
  alias Huddlz.Notifications

  @impl true
  def change(changeset, _opts, _context) do
    changeset
    |> Ash.Changeset.force_change_attribute(:join_suggestions_sent_at, DateTime.utc_now())
    |> Ash.Changeset.after_action(fn _cs, huddl -> fan_out(huddl) end)
  end

  defp fan_out(huddl) do
    huddl = Ash.load!(huddl, [:group], authorize?: false)

    huddl.id
    |> Communities.list_huddl_attendees!(authorize?: false)
    |> Enum.map(& &1.user_id)
    |> people()
    |> Enum.filter(&Communities.drop_in?(&1, huddl.group_id))
    |> Enum.each(&suggest(&1, huddl))

    {:ok, huddl}
  end

  defp people([]), do: []

  defp people(user_ids) do
    User
    |> Ash.Query.filter(id in ^user_ids and is_nil(suspended_at))
    |> Ash.read!(authorize?: false)
  end

  defp suggest(user, huddl) do
    case Communities.mark_join_suggestion_emailed(
           %{group_id: huddl.group_id, user_id: user.id},
           authorize?: false
         ) do
      {:ok, _reminder} -> Notifications.deliver(user, :group_join_suggestion, payload(huddl))
      {:error, _already_suggested} -> :ok
    end
  end

  defp payload(huddl) do
    %{
      "huddl_id" => huddl.id,
      "huddl_title" => to_string(huddl.title),
      "group_id" => huddl.group_id,
      "group_name" => to_string(huddl.group.name),
      "group_slug" => to_string(huddl.group.slug),
      "starts_at_iso" => DateTime.to_iso8601(huddl.starts_at),
      "time_zone" => huddl.time_zone
    }
  end
end
