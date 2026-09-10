defmodule Huddlz.Communities.GroupStats do
  @moduledoc """
  The figures behind a group's organizer overview, for a chosen period.
  Reached through the group's `:overview` action (`Communities.group_overview/3`),
  which authorizes the actor; the reads here trust that boundary.

  Everything here is derived from rows the app already keeps: member join
  dates, RSVP times and waitlist times. Members who left and RSVPs that
  were cancelled leave no trace yet, so growth is "as it stands today by
  join date" and RSVP counts are of RSVPs still standing.

  Periods are `"30d"`, `"90d"` (the default) and `"12m"`. Each is split
  into equal buckets for the sparklines: six for the day periods, twelve
  for the year.
  """

  require Ash.Query

  alias Huddlz.Communities.{GroupMember, HuddlAttendee}

  @periods [
    {"30d", %{days: 30, buckets: 6, label: "30 days"}},
    {"90d", %{days: 90, buckets: 6, label: "90 days"}},
    {"12m", %{days: 365, buckets: 12, label: "12 months"}}
  ]
  @default_period "90d"

  @type period :: String.t()

  @doc "Period keys and their labels, in display order."
  def periods, do: Enum.map(@periods, fn {key, %{label: label}} -> {key, label} end)

  @doc "The period a URL parameter names, falling back to the default."
  def parse_period(param) when is_binary(param) do
    if List.keymember?(@periods, param, 0), do: param, else: @default_period
  end

  def parse_period(_), do: @default_period

  def default_period, do: @default_period

  def period_label(period), do: period_spec(period).label

  @doc """
  Overview figures for a group over a period. Called by
  `Huddlz.Communities.Group.Actions.Overview` once the actor is authorized;
  reach it through `Huddlz.Communities.group_overview/3`, not directly.

    * `members` — current member count, how many joined this calendar
      month in the group's time zone, and a cumulative sparkline
    * `rsvps` — RSVPs made in the period, the count in the period before
      it, and a per-bucket sparkline
    * `waitlist` — people waitlisted on upcoming huddlz right now, the
      titles of the huddlz that are full, and a cumulative sparkline
  """
  def compute(group, period, now \\ DateTime.utc_now()) do
    spec = period_spec(period)
    edges = bucket_edges(now, spec)

    %{
      period: period,
      members: members(group, now, edges),
      rsvps: rsvps(group, now, spec, edges),
      waitlist: waitlist(group, now, edges)
    }
  end

  defp members(group, now, edges) do
    joined_at =
      GroupMember
      |> Ash.Query.filter(group_id == ^group.id)
      |> Ash.Query.select([:created_at])
      |> Ash.read!(authorize?: false)
      |> Enum.map(& &1.created_at)

    month_start = start_of_month(now, group.time_zone)

    %{
      count: length(joined_at),
      joined_this_month: Enum.count(joined_at, &(DateTime.compare(&1, month_start) != :lt)),
      spark: cumulative(joined_at, edges)
    }
  end

  defp rsvps(group, now, spec, edges) do
    period_start = DateTime.add(now, -spec.days, :day)
    previous_start = DateTime.add(period_start, -spec.days, :day)

    rsvped_at =
      HuddlAttendee
      |> Ash.Query.filter(
        huddl.group_id == ^group.id and is_nil(waitlisted_at) and rsvped_at >= ^previous_start
      )
      |> Ash.Query.select([:rsvped_at])
      |> Ash.read!(authorize?: false)
      |> Enum.map(& &1.rsvped_at)

    {current, previous} = Enum.split_with(rsvped_at, &(DateTime.compare(&1, period_start) != :lt))

    %{
      count: length(current),
      previous: length(previous),
      spark: per_bucket(current, edges)
    }
  end

  defp waitlist(group, now, edges) do
    rows =
      HuddlAttendee
      |> Ash.Query.filter(
        huddl.group_id == ^group.id and not is_nil(waitlisted_at) and
          huddl.lifecycle_state == :published and huddl.ends_at > ^now
      )
      |> Ash.Query.load(huddl: [:title])
      |> Ash.read!(authorize?: false)

    %{
      count: length(rows),
      full_huddlz: rows |> Enum.map(& &1.huddl.title) |> Enum.uniq(),
      spark: cumulative(Enum.map(rows, & &1.waitlisted_at), edges)
    }
  end

  # One point per bucket: how many timestamps fall inside it.
  defp per_bucket(timestamps, edges) do
    edges
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [from, to] ->
      Enum.count(timestamps, fn t ->
        DateTime.compare(t, from) != :lt and DateTime.compare(t, to) == :lt
      end)
    end)
  end

  # One point per bucket end: how many timestamps fall on or before it.
  defp cumulative(timestamps, [_first | ends]) do
    Enum.map(ends, fn to -> Enum.count(timestamps, &(DateTime.compare(&1, to) != :gt)) end)
  end

  # `buckets + 1` instants from the start of the period up to now.
  defp bucket_edges(now, %{days: days, buckets: buckets}) do
    seconds = days * 86_400
    start = DateTime.add(now, -seconds, :second)
    Enum.map(0..buckets, fn i -> DateTime.add(start, div(seconds * i, buckets), :second) end)
  end

  defp start_of_month(now, time_zone) do
    local = DateTime.shift_zone!(now, time_zone)

    local
    |> DateTime.to_date()
    |> Date.beginning_of_month()
    |> DateTime.new!(~T[00:00:00], time_zone)
    |> DateTime.shift_zone!("Etc/UTC")
  end

  defp period_spec(period) do
    {_key, spec} = List.keyfind(@periods, period, 0) || List.keyfind(@periods, @default_period, 0)
    spec
  end
end
