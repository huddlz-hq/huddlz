defmodule Huddlz.Communities.GroupStats do
  @moduledoc """
  The figures behind a group's organizer overview, for a chosen period.
  Reached through the group's `:overview` action (`Communities.group_overview/3`),
  which authorizes the actor; the reads here trust that boundary.

  Everything here is derived from rows the app already keeps: member join
  dates, RSVP times and waitlist times, plus the group activity log for
  what those rows forget. Leaves come from the log, and so do the joins of
  people who have since left; members at any past moment are counted back
  from today's members through those joins and leaves. The signup curves
  are rebuilt the same way from cancelled RSVPs and promotions from the
  waitlist. The RSVP tile counts RSVPs still standing.

  Periods and their buckets are `Huddlz.Communities.Periods`'s, shared
  with the platform overview; month boundaries fall in the group's time
  zone.

  The next huddl's signup curve is one point per day since it was
  published: how many RSVPs stood at the end of that day, cancellations
  and all. The group's typical curve is the same measure averaged over its
  past huddlz, drawn only once there are three of them to average.

  Turnout comes from the counts organizers record after a huddl ends. The
  show rate over a period is turnout divided by RSVPs across the counted
  huddlz that ended in it. The next huddl's expected turnout applies the
  show rate of counted huddlz of its own type from the last year, once
  there are three of them.
  """

  require Ash.Query

  alias Huddlz.Communities.{GroupActivity, GroupMember, Huddl, HuddlAttendee, Periods}

  @day 86_400
  @typical_min_history 3
  @expected_min_history 3
  @expected_history_days 365
  @turnout_chart_limit 8

  @type period :: Periods.period()

  defdelegate periods, to: Periods
  defdelegate parse_period(param), to: Periods
  defdelegate default_period, to: Periods
  defdelegate period_label(period), to: Periods

  @doc """
  Overview figures for a group over a period. Called by
  `Huddlz.Communities.Group.Actions.Overview` once the actor is authorized;
  reach it through `Huddlz.Communities.group_overview/3`, not directly.
  The actor is the organizer asking, used to read the group's huddlz
  through the organizer read.

    * `members` — current member count, how many joined this calendar
      month in the group's time zone, and a sparkline of members over time
    * `growth` — the period bucketed by month, fortnight or week: members
      at each bucket's end, how many joined and left in it, and the totals
      joined, left and gained (net)
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
    spec = Periods.spec(period)
    edges = Periods.bucket_edges(now, spec)
    membership = membership_history(group)
    past = organizer_huddlz(group, actor, :past, starts_at: :desc)

    %{
      period: period,
      members: members(membership, group, now, edges),
      growth: growth(membership, group, now, spec),
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

  # Today's members as joins at their join time, merged with the log's
  # joins, acceptances and leaves. Accepting an invitation while already a
  # member is not another join.
  defp membership_history(group) do
    rows =
      GroupMember
      |> Ash.Query.filter(group_id == ^group.id)
      |> Ash.Query.select([:user_id, :created_at])
      |> Ash.read!(authorize?: false)

    activity =
      GroupActivity
      |> Ash.Query.filter(
        group_id == ^group.id and kind in [:joined, :accepted_invitation, :left]
      )
      |> Ash.Query.select([:user_id, :kind, :occurred_at])
      |> Ash.read!(authorize?: false)

    current_joins =
      Enum.map(rows, &%{kind: :joined, user_id: &1.user_id, occurred_at: &1.created_at})

    runs = runs(current_joins ++ activity, :left)
    %{count: length(rows), joined_at: runs.started_at, left_at: runs.ended_at}
  end

  # Walk entries in time order, one person at a time: a start counts only
  # when the person is not already in, and the ending kind closes the run.
  # Endings are kept even without a known start, so a join or RSVP from
  # before the log existed shows its end and not its start.
  defp runs(entries, ending) do
    {_in, started_at} =
      entries
      |> Enum.sort_by(& &1.occurred_at, DateTime)
      |> Enum.reduce({MapSet.new(), []}, fn
        %{kind: ^ending, user_id: user_id}, {present, started_at} ->
          {MapSet.delete(present, user_id), started_at}

        %{user_id: user_id, occurred_at: at}, {present, started_at} ->
          if MapSet.member?(present, user_id) do
            {present, started_at}
          else
            {MapSet.put(present, user_id), [at | started_at]}
          end
      end)

    %{
      started_at: started_at,
      ended_at: for(%{kind: ^ending, occurred_at: at} <- entries, do: at)
    }
  end

  defp members(membership, group, now, edges) do
    month_start = Periods.start_of_month(now, group.time_zone)
    [_first | ends] = edges

    %{
      count: membership.count,
      joined_this_month:
        Enum.count(membership.joined_at, &(DateTime.compare(&1, month_start) != :lt)),
      spark: Enum.map(ends, &members_at(membership, &1))
    }
  end

  # Members at the end of each bucket, counted back from today's members
  # through the joins and leaves since, with the joins and leaves inside
  # each bucket.
  defp growth(membership, group, now, spec) do
    buckets =
      now
      |> Periods.growth_buckets(spec, group.time_zone)
      |> Enum.map(fn {label, from, to} ->
        %{
          label: label,
          starts_at: from,
          ends_at: to,
          joined: Enum.count(membership.joined_at, &Periods.within?(&1, from, to)),
          left: Enum.count(membership.left_at, &Periods.within?(&1, from, to)),
          members: members_at(membership, to)
        }
      end)

    joined = buckets |> Enum.map(& &1.joined) |> Enum.sum()
    left = buckets |> Enum.map(& &1.left) |> Enum.sum()

    %{
      unit: spec.growth,
      joined: joined,
      left: left,
      gained: joined - left,
      buckets: buckets
    }
  end

  # Today's count, minus everyone who joined after the moment, plus
  # everyone who left after it. The last point is always today's count.
  defp members_at(membership, at),
    do: count_at(membership.count, membership.joined_at, membership.left_at, at)

  defp count_at(count, started_at, ended_at, at),
    do: count - since(started_at, at) + since(ended_at, at)

  defp since(timestamps, at), do: Enum.count(timestamps, &(DateTime.compare(&1, at) != :lt))

  defp rsvps(group, now, spec, edges) do
    {period_start, previous_start} = Periods.starts(now, spec)

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
      spark: Periods.per_bucket(current, edges)
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
      spark: Periods.cumulative(Enum.map(rows, & &1.waitlisted_at), edges)
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
          curve: standing_by_day(next, rsvp_histories([next.id]), published_at, days),
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
      histories = rsvp_histories(Enum.map(past, & &1.id))

      past
      |> Enum.map(&standing_by_day(&1, histories, &1.published_at, days))
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

  # Each huddl's RSVP history, built like the membership history: today's
  # standing rows as RSVPs at their RSVP time, or at their promotion when
  # the log has one, merged with the log's RSVPs, promotions and
  # cancellations. Waitlist entries and withdrawals do not move the curve.
  defp rsvp_histories(huddl_ids) do
    rows =
      HuddlAttendee
      |> Ash.Query.filter(huddl_id in ^huddl_ids and is_nil(waitlisted_at))
      |> Ash.Query.select([:huddl_id, :user_id, :rsvped_at])
      |> Ash.read!(authorize?: false)

    activity =
      GroupActivity
      |> Ash.Query.filter(
        huddl_id in ^huddl_ids and kind in [:rsvped, :promoted, :cancelled_rsvp]
      )
      |> Ash.Query.select([:huddl_id, :user_id, :kind, :occurred_at])
      |> Ash.read!(authorize?: false)

    promoted_at =
      activity
      |> Enum.filter(&(&1.kind == :promoted))
      |> Enum.group_by(&{&1.huddl_id, &1.user_id}, & &1.occurred_at)
      |> Map.new(fn {key, times} -> {key, Enum.max(times, DateTime)} end)

    standing =
      Enum.map(rows, fn row ->
        %{
          kind: :rsvped,
          huddl_id: row.huddl_id,
          user_id: row.user_id,
          occurred_at: latest(row.rsvped_at, promoted_at[{row.huddl_id, row.user_id}])
        }
      end)

    (standing ++ activity)
    |> Enum.group_by(& &1.huddl_id)
    |> Map.new(fn {huddl_id, entries} -> {huddl_id, runs(entries, :cancelled_rsvp)} end)
  end

  defp latest(at, nil), do: at
  defp latest(at, other), do: if(DateTime.compare(other, at) == :gt, do: other, else: at)

  # One point per day from publish: RSVPs standing at the end of that day,
  # counted back from today's count through the RSVPs and cancellations
  # since. The last point is always today's count.
  defp standing_by_day(huddl, histories, published_at, days) do
    history = Map.get(histories, huddl.id, %{started_at: [], ended_at: []})

    Enum.map(0..days, fn d ->
      day_end = DateTime.add(published_at, (d + 1) * @day, :second)
      count_at(huddl.rsvp_count, history.started_at, history.ended_at, day_end)
    end)
  end

  defp days_between(from, to), do: max(div(DateTime.diff(to, from, :second), @day), 0)
end
