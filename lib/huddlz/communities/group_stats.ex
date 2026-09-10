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
  for the year. Member growth buckets by calendar month for the year, by
  fortnight for 90 days and by week for 30 days, the last bucket running
  up to now.

  The next huddl's signup curve is one point per day since it was
  published: how many RSVPs stood by the end of that day. The group's
  typical curve is the same measure averaged over its past huddlz, drawn
  only once there are three of them to average.

  Turnout comes from the counts organizers record after a huddl ends. The
  show rate over a period is turnout divided by RSVPs across the counted
  huddlz that ended in it. The next huddl's expected turnout applies the
  show rate of counted huddlz of its own type from the last year, once
  there are three of them.
  """

  require Ash.Query

  alias Huddlz.Communities.{GroupMember, Huddl, HuddlAttendee}

  @day 86_400
  @typical_min_history 3
  @expected_min_history 3
  @expected_history_days 365
  @turnout_chart_limit 8

  @periods [
    {"30d", %{days: 30, buckets: 6, label: "30 days", growth: :week}},
    {"90d", %{days: 90, buckets: 6, label: "90 days", growth: :fortnight}},
    {"12m", %{days: 365, buckets: 12, label: "12 months", growth: :month}}
  ]
  @growth_bucket_days %{week: 7, fortnight: 14}
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
  The actor is the organizer asking, used to read the group's huddlz
  through the organizer read.

    * `members` — current member count, how many joined this calendar
      month in the group's time zone, and a cumulative sparkline
    * `growth` — the period bucketed by month, fortnight or week: members
      at each bucket's end, how many joined in it, and the total gained
    * `rsvps` — RSVPs made in the period, the count in the period before
      it, and a per-bucket sparkline
    * `waitlist` — people waitlisted on upcoming huddlz right now, the
      titles of the huddlz that are full, and a cumulative sparkline
    * `turnout` — counted huddlz that ended in the period: how many, their
      RSVPs and turnout, the show rate (nil without counts) and a
      sparkline of per-huddl show rates
    * `turnout_chart` — the last few past huddlz, oldest first, each with
      RSVPs, capacity and turnout (room and call) or marked uncounted
    * `next_huddl` — the next upcoming huddl with its RSVPs, capacity,
      signup curve since publish, the group's typical curve (or nil), the
      expected turnout (or nil) and the other upcoming huddlz; nil when
      nothing is upcoming
  """
  def compute(group, period, actor, now \\ DateTime.utc_now()) do
    spec = period_spec(period)
    edges = bucket_edges(now, spec)
    joined_at = member_join_times(group)
    past = organizer_huddlz(group, actor, :past, starts_at: :desc)

    %{
      period: period,
      members: members(joined_at, group, now, edges),
      growth: growth(joined_at, group, now, spec),
      rsvps: rsvps(group, now, spec, edges),
      waitlist: waitlist(group, now, edges),
      turnout: turnout(past, now, spec),
      turnout_chart: turnout_chart(past),
      next_huddl: next_huddl(group, actor, past, now)
    }
  end

  defp turnout(past, now, spec) do
    period_start = DateTime.add(now, -spec.days, :day)

    counted =
      Enum.filter(past, &(counted?(&1) and DateTime.compare(&1.ends_at, period_start) != :lt))

    rsvps = counted |> Enum.map(& &1.rsvp_count) |> Enum.sum()
    came = counted |> Enum.map(&turnout_total/1) |> Enum.sum()

    %{
      counted: length(counted),
      rsvps: rsvps,
      turnout: came,
      show_rate: show_rate(came, rsvps),
      spark:
        counted
        |> Enum.reverse()
        |> Enum.map(&show_rate(turnout_total(&1), &1.rsvp_count))
        |> Enum.reject(&is_nil/1)
    }
  end

  defp turnout_chart(past) do
    past
    |> Enum.take(@turnout_chart_limit)
    |> Enum.reverse()
    |> Enum.map(fn huddl ->
      %{
        id: huddl.id,
        title: huddl.title,
        starts_at: huddl.starts_at,
        time_zone: huddl.time_zone,
        rsvp_count: huddl.rsvp_count,
        capacity: huddl.max_attendees,
        counted?: counted?(huddl),
        in_room: huddl.turnout_in_room,
        on_call: huddl.turnout_on_call,
        turnout: if(counted?(huddl), do: turnout_total(huddl))
      }
    end)
  end

  # About how many to expect at the next huddl: the show rate of counted
  # huddlz of the same type in the last year, applied to its RSVPs.
  defp expected_turnout(next, past, now) do
    since = DateTime.add(now, -@expected_history_days, :day)

    alike =
      Enum.filter(past, fn huddl ->
        counted?(huddl) and huddl.event_type == next.event_type and
          DateTime.compare(huddl.ends_at, since) != :lt
      end)

    rsvps = alike |> Enum.map(& &1.rsvp_count) |> Enum.sum()

    if length(alike) >= @expected_min_history and rsvps > 0 do
      came = alike |> Enum.map(&turnout_total/1) |> Enum.sum()
      %{count: round(came * next.rsvp_count / rsvps), from: length(alike)}
    end
  end

  defp counted?(huddl), do: not is_nil(huddl.turnout_recorded_at)

  defp turnout_total(huddl), do: (huddl.turnout_in_room || 0) + (huddl.turnout_on_call || 0)

  defp show_rate(_came, 0), do: nil
  defp show_rate(came, rsvps), do: round(came * 100 / rsvps)

  defp member_join_times(group) do
    GroupMember
    |> Ash.Query.filter(group_id == ^group.id)
    |> Ash.Query.select([:created_at])
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.created_at)
  end

  defp members(joined_at, group, now, edges) do
    month_start = start_of_month(now, group.time_zone)

    %{
      count: length(joined_at),
      joined_this_month: Enum.count(joined_at, &(DateTime.compare(&1, month_start) != :lt)),
      spark: cumulative(joined_at, edges)
    }
  end

  # Members at the end of each bucket, reconstructed from the join dates of
  # today's members, with the joins inside each bucket.
  defp growth(joined_at, group, now, spec) do
    buckets =
      group
      |> growth_buckets(now, spec)
      |> Enum.map(fn {label, from, to} ->
        %{
          label: label,
          starts_at: from,
          ends_at: to,
          joined: Enum.count(joined_at, &within?(&1, from, to)),
          members: Enum.count(joined_at, &(DateTime.compare(&1, to) == :lt))
        }
      end)

    %{
      unit: spec.growth,
      gained: buckets |> Enum.map(& &1.joined) |> Enum.sum(),
      buckets: buckets
    }
  end

  # Twelve calendar months in the group's time zone, this month last.
  defp growth_buckets(group, now, %{growth: :month, buckets: count}) do
    this_month = start_of_month(now, group.time_zone)

    starts =
      Enum.map((count - 1)..0//-1, fn back ->
        shift_months(this_month, -back, group.time_zone)
      end)

    starts
    |> Enum.zip(tl(starts) ++ [now])
    |> Enum.map(fn {from, to} ->
      {from |> DateTime.shift_zone!(group.time_zone) |> Calendar.strftime("%b"), from, to}
    end)
  end

  # Whole weeks or fortnights from the start of the period, the last one
  # running up to now.
  defp growth_buckets(group, now, %{growth: unit, days: days}) do
    bucket_days = @growth_bucket_days[unit]
    start = DateTime.add(now, -days, :day)

    0..(days - 1)//bucket_days
    |> Enum.map(fn offset ->
      from = DateTime.add(start, offset, :day)
      to = DateTime.add(from, bucket_days, :day)
      {label_date(from, group.time_zone), from, min_datetime(to, now)}
    end)
  end

  defp within?(t, from, to),
    do: DateTime.compare(t, from) != :lt and DateTime.compare(t, to) == :lt

  defp min_datetime(a, b), do: if(DateTime.compare(a, b) == :gt, do: b, else: a)

  defp label_date(at, time_zone),
    do: at |> DateTime.shift_zone!(time_zone) |> Calendar.strftime("%b %-d")

  defp shift_months(month_start, months, time_zone) do
    month_start
    |> DateTime.shift_zone!(time_zone)
    |> DateTime.to_date()
    |> Date.shift(month: months)
    |> DateTime.new!(~T[00:00:00], time_zone)
    |> DateTime.shift_zone!("Etc/UTC")
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

  defp next_huddl(group, actor, past, now) do
    case organizer_huddlz(group, actor, :published, starts_at: :asc) do
      [] ->
        nil

      [next | others] ->
        published_at = next.published_at || next.inserted_at
        days = days_between(published_at, now)

        next
        |> huddl_summary()
        |> Map.merge(%{
          published_at: published_at,
          days: days,
          curve:
            cumulative_by_day(standing_rsvp_times([next.id])[next.id] || [], published_at, days),
          typical: typical_curve(past, days),
          expected: expected_turnout(next, past, now),
          others: Enum.map(others, &huddl_summary/1)
        })
    end
  end

  # The group's past huddlz averaged day by day since each was published.
  # Nil until there are enough of them for an average to mean anything.
  defp typical_curve(past, days) do
    past = Enum.reject(past, &is_nil(&1.published_at))

    if length(past) < @typical_min_history do
      nil
    else
      times = standing_rsvp_times(Enum.map(past, & &1.id))

      past
      |> Enum.map(&cumulative_by_day(times[&1.id] || [], &1.published_at, days))
      |> Enum.zip_with(fn counts -> Float.round(Enum.sum(counts) / length(counts), 1) end)
    end
  end

  defp organizer_huddlz(group, actor, state, sort) do
    Huddl
    |> Ash.Query.for_read(:huddlz_for_organizer, %{state: state}, actor: actor)
    |> Ash.Query.filter(group_id == ^group.id)
    |> Ash.Query.sort(sort)
    |> Ash.Query.load([:rsvp_count, :waitlist_count])
    |> Ash.read!(actor: actor)
  end

  defp huddl_summary(huddl) do
    %{
      id: huddl.id,
      title: huddl.title,
      starts_at: huddl.starts_at,
      time_zone: huddl.time_zone,
      event_type: huddl.event_type,
      rsvp_count: huddl.rsvp_count,
      capacity: huddl.max_attendees,
      waitlist_count: huddl.waitlist_count
    }
  end

  # Standing (non-waitlisted) RSVP times, grouped by huddl.
  defp standing_rsvp_times(huddl_ids) do
    HuddlAttendee
    |> Ash.Query.filter(huddl_id in ^huddl_ids and is_nil(waitlisted_at))
    |> Ash.Query.select([:huddl_id, :rsvped_at])
    |> Ash.read!(authorize?: false)
    |> Enum.group_by(& &1.huddl_id, & &1.rsvped_at)
  end

  # One point per day from publish: RSVPs standing by the end of that day.
  defp cumulative_by_day(timestamps, published_at, days) do
    Enum.map(0..days, fn d ->
      day_end = DateTime.add(published_at, (d + 1) * @day, :second)
      Enum.count(timestamps, &(DateTime.compare(&1, day_end) == :lt))
    end)
  end

  defp days_between(from, to), do: max(div(DateTime.diff(to, from, :second), @day), 0)

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
