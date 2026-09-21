defmodule Huddlz.Admin.DropInStats do
  @moduledoc """
  The Drop-ins figures of the admin overview: how many RSVPs came from people
  who had not joined the hosting group, what those people did next, where
  their joins came from, and what the join suggestion emails led to.

  Counts only. The numbers are small, and a rate would overstate them.

  Called by `Huddlz.Admin.PlatformStats`, which has already narrowed the
  window to the groups and huddlz the administrator may see; the reads here
  trust that boundary.

  A drop-in RSVP is a standing RSVP made while the person was not a member of
  the hosting group. Membership at a moment is read from the membership row
  (a member since it was created) and, for memberships that have ended, from
  the group activity log: the last joined, accepted or left entry before the
  moment says whether they belonged then.

  What they did next is counted once per person per group, from their first
  drop-in RSVP of the period, and the first match wins: joined the group,
  RSVPd to another huddl of the group without joining, or neither.
  """

  require Ash.Query

  alias Huddlz.Accounts.User
  alias Huddlz.Communities.{DropInReminder, GroupActivity, GroupMember, HuddlAttendee, JoinSource}
  alias Huddlz.Notifications

  @membership_kinds [:joined, :accepted_invitation, :left]

  @doc """
  The figures for a window, given its standing RSVPs.

    * `rsvps` of `total_rsvps` — drop-in RSVPs of the period, and every RSVP
      of the period (the RSVPs figure of the overview)
    * `people`, `groups` — the distinct people behind the drop-in RSVPs, and
      the distinct groups they dropped in on
    * `next` — per person per group: `joined`, `rsvped_again`, `nothing`
    * `join_sources` — the `joined` count split by source, every source
      listed, `nil` last for joins with no recorded source
    * `suggestions` — join suggestion emails sent in the period, and per
      suggestion, first match wins: `joined`, `dismissed` (Not now),
      `turned_off` (the email preference is off now), `nothing`
    * `measured_since` — the date of the earliest RSVP on record when the
      period reaches back before it, otherwise nil
  """
  def compute(rsvps, %{start: start} = window) do
    current = Enum.filter(rsvps, &(DateTime.compare(&1.rsvped_at, start) != :lt))
    reminders = emailed_reminders(window)

    history =
      history(window, Enum.map(current, & &1.user_id) ++ Enum.map(reminders, & &1.user_id))

    drop_ins = Enum.reject(current, &member_at?(history, pair(&1), &1.rsvped_at))
    outcomes = Enum.map(first_drop_ins(drop_ins), &outcome(&1, rsvps, history))
    joins = for {:joined, source} <- outcomes, do: source

    %{
      rsvps: length(drop_ins),
      total_rsvps: length(current),
      people: drop_ins |> Enum.map(& &1.user_id) |> Enum.uniq() |> length(),
      groups: drop_ins |> Enum.map(& &1.group_id) |> Enum.uniq() |> length(),
      next: %{
        joined: length(joins),
        rsvped_again: Enum.count(outcomes, &(&1 == :rsvped_again)),
        nothing: Enum.count(outcomes, &(&1 == :nothing))
      },
      join_sources: join_sources(joins),
      suggestions: suggestions(reminders, history),
      measured_since: measured_since(window)
    }
  end

  defp pair(%{user_id: user_id, group_id: group_id}), do: {user_id, group_id}

  # Membership rows and membership log entries of the people in question,
  # by person and group.
  defp history(%{group_ids: group_ids}, user_ids) do
    user_ids = Enum.uniq(user_ids)

    members =
      GroupMember
      |> Ash.Query.filter(group_id in ^group_ids and user_id in ^user_ids)
      |> Ash.Query.select([:user_id, :group_id, :created_at, :join_source])
      |> Ash.read!(authorize?: false)
      |> Map.new(&{pair(&1), &1})

    log =
      GroupActivity
      |> Ash.Query.filter(
        group_id in ^group_ids and user_id in ^user_ids and kind in ^@membership_kinds
      )
      |> Ash.Query.select([:user_id, :group_id, :kind, :occurred_at, :source])
      |> Ash.Query.sort(occurred_at: :asc)
      |> Ash.read!(authorize?: false)
      |> Enum.group_by(&pair/1)

    %{members: members, log: log}
  end

  defp member_at?(%{members: members, log: log}, pair, at) do
    case members[pair] do
      %{created_at: since} when not is_nil(since) ->
        DateTime.compare(since, at) != :gt or belonged_by_log?(log[pair], at)

      _ ->
        belonged_by_log?(log[pair], at)
    end
  end

  # The last membership entry at or before the moment decides.
  defp belonged_by_log?(nil, _at), do: false

  defp belonged_by_log?(entries, at) do
    entries
    |> Enum.take_while(&(DateTime.compare(&1.occurred_at, at) != :gt))
    |> List.last()
    |> case do
      %{kind: kind} when kind in [:joined, :accepted_invitation] -> true
      _ -> false
    end
  end

  # The first join after a moment, as `{at, source}`, or nil. The membership
  # row and its log entry describe the same join; the log alone remembers a
  # join the person has since left.
  defp join_after(%{members: members, log: log}, pair, at) do
    from_row =
      case members[pair] do
        %{created_at: since, join_source: source} when not is_nil(since) -> [{since, source}]
        _ -> []
      end

    from_log =
      for %{kind: kind} = entry <- log[pair] || [], kind in [:joined, :accepted_invitation] do
        {entry.occurred_at, entry.source}
      end

    (from_row ++ from_log)
    |> Enum.filter(fn {joined_at, _source} -> DateTime.compare(joined_at, at) == :gt end)
    |> Enum.min_by(fn {joined_at, _source} -> DateTime.to_unix(joined_at, :microsecond) end, fn ->
      nil
    end)
  end

  defp first_drop_ins(drop_ins) do
    drop_ins
    |> Enum.group_by(&pair/1)
    |> Enum.map(fn {_pair, rsvps} -> Enum.min_by(rsvps, & &1.rsvped_at, DateTime) end)
  end

  defp outcome(first, rsvps, history) do
    case join_after(history, pair(first), first.rsvped_at) do
      {_at, source} -> {:joined, source}
      nil -> if rsvped_again?(first, rsvps), do: :rsvped_again, else: :nothing
    end
  end

  defp rsvped_again?(first, rsvps) do
    Enum.any?(rsvps, fn rsvp ->
      pair(rsvp) == pair(first) and rsvp.huddl_id != first.huddl_id and
        DateTime.compare(rsvp.rsvped_at, first.rsvped_at) == :gt
    end)
  end

  defp join_sources(joins) do
    counts = Enum.frequencies(joins)
    Enum.map(JoinSource.values() ++ [nil], &%{source: &1, count: Map.get(counts, &1, 0)})
  end

  defp emailed_reminders(%{start: start, now: now, group_ids: group_ids}) do
    DropInReminder
    |> Ash.Query.filter(group_id in ^group_ids and emailed_at >= ^start and emailed_at <= ^now)
    |> Ash.Query.select([:user_id, :group_id, :emailed_at, :dismissed_at])
    |> Ash.read!(authorize?: false)
  end

  defp suggestions(reminders, history) do
    turned_off = turned_off(reminders)

    outcomes =
      Enum.map(reminders, fn reminder ->
        cond do
          join_after(history, pair(reminder), reminder.emailed_at) -> :joined
          reminder.dismissed_at -> :dismissed
          MapSet.member?(turned_off, reminder.user_id) -> :turned_off
          true -> :nothing
        end
      end)

    counts = Enum.frequencies(outcomes)

    %{
      emailed: length(reminders),
      joined: Map.get(counts, :joined, 0),
      dismissed: Map.get(counts, :dismissed, 0),
      turned_off: Map.get(counts, :turned_off, 0),
      nothing: Map.get(counts, :nothing, 0)
    }
  end

  # The people among them whose join suggestion email is off now. When they
  # turned it off is not kept.
  defp turned_off([]), do: MapSet.new()

  defp turned_off(reminders) do
    user_ids = reminders |> Enum.map(& &1.user_id) |> Enum.uniq()

    User
    |> Ash.Query.filter(id in ^user_ids)
    |> Ash.Query.select([:id, :notification_preferences])
    |> Ash.read!(authorize?: false)
    |> Enum.reject(&Notifications.preference_for(&1, :group_join_suggestion))
    |> MapSet.new(& &1.id)
  end

  defp measured_since(%{start: start, huddl_ids: huddl_ids}) do
    HuddlAttendee
    |> Ash.Query.filter(huddl_id in ^huddl_ids and is_nil(waitlisted_at))
    |> Ash.Query.select([:rsvped_at])
    |> Ash.Query.sort(rsvped_at: :asc)
    |> Ash.Query.limit(1)
    |> Ash.read_one!(authorize?: false)
    |> case do
      %{rsvped_at: earliest} ->
        if DateTime.compare(earliest, start) == :gt, do: DateTime.to_date(earliest)

      nil ->
        nil
    end
  end
end
