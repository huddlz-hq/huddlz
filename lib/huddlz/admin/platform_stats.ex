defmodule Huddlz.Admin.PlatformStats do
  @moduledoc """
  The figures behind the admin overview, for a chosen period. Reached
  through `Huddlz.Admin.platform_overview/2`, which lets only
  administrators in; the reads here trust that boundary. The actor is
  passed along so group and huddl reads follow the administrator's ordinary
  visibility. Private-group analytics additionally require an owner or
  organizer role, as on the group's overview.

  Every definition is the organizer overview's (`Huddlz.Communities.GroupStats`)
  so a number means the same thing on `/admin` and on a group's page:
  RSVPs are the rows still standing, huddlz held are published huddlz
  that ended, and the show rate is turnout divided by RSVPs across the
  counted huddlz. The platform has no single time zone, so buckets and
  "today" run on UTC days.

  People are confirmed accounts. Active people are the distinct people
  with an `Huddlz.Accounts.ActiveDay` in the period; measurement began
  on the separately recorded collection date. Figures say so rather than
  compare against days nobody measured.
  """

  require Ash.Query

  alias Huddlz.Accounts.{ActiveDay, UsageMeasurement, User}
  alias Huddlz.Admin.DropInStats
  alias Huddlz.Communities.{Group, Huddl, Periods, RsvpMoment}

  @coming_up_days 30
  @coming_up_limit 5
  @active_groups_limit 8

  @doc """
  Overview figures for the platform over a period.

    * `people` — confirmed accounts now, how many signed up in the period,
      and a sparkline of recorded sign-ups; historical estimates are excluded
    * `active` — distinct people who used huddlz on a day in the period,
      the count for the period before (nil unless measurement covers all
      of it), a per-bucket sparkline (nil for buckets that ended before
      measurement began) and the first measured day
    * `groups` — live groups now, how many started in the period, how
      many held a huddl in it, and a sparkline of live groups over time
    * `held` — huddlz held in the period, the count in the period before,
      a per-bucket sparkline, and growth buckets with held and cancelled
    * `rsvps` — RSVPs made in the period, the count before, and a sparkline
    * `turnout` — the past huddlz of the period: how many were counted,
      skipped or never answered, the show rate over the counted ones (nil
      without counts), and per-huddl show rates oldest first
    * `active_groups` — the groups with the most RSVPs in the period,
      each with huddlz held, RSVPs, show rate (nil when never counted)
      and members; then how many live groups held nothing and how many
      of those never held a huddl at all
    * `coming_up` — the next 30 days: huddlz scheduled, RSVPs so far,
      groups with something on, and the next few huddlz
    * `drop_ins` — RSVPs from people who had not joined the hosting group
      and what followed; see `Huddlz.Admin.DropInStats`
  """
  def compute(period, actor, now \\ DateTime.utc_now()) do
    window = now |> Periods.calendar_window(Periods.spec(period)) |> Map.put(:actor, actor)

    groups = groups(actor)
    window = Map.put(window, :group_ids, Enum.map(groups, & &1.id))
    huddl_groups = visible_huddlz(window)
    window = Map.merge(window, %{huddl_ids: Map.keys(huddl_groups), huddl_groups: huddl_groups})
    ended = ended_huddlz(window)
    rsvps = standing_rsvps(window)

    %{
      period: period,
      people: people(window),
      active: active_people(window),
      groups: group_figures(groups, ended, window),
      held: held(ended, window),
      rsvps: rsvp_figures(rsvps, window),
      turnout: turnout(ended, window),
      active_groups: active_groups(groups, ended, rsvps, window),
      coming_up: coming_up(window),
      drop_ins: DropInStats.compute(rsvps, window)
    }
  end

  defp people(%{start: start, now: now, edges: edges}) do
    users =
      User
      |> Ash.Query.filter(not is_nil(confirmed_at))
      |> Ash.Query.select([:inserted_at, :signup_date_source])
      |> Ash.read!(authorize?: false)

    {recorded, estimated} = Enum.split_with(users, &(&1.signup_date_source == :recorded))
    signed_up = Enum.map(recorded, & &1.inserted_at)

    %{
      count: length(users),
      joined: Enum.count(signed_up, &Periods.within?(&1, start, now)),
      estimated: length(estimated),
      spark: Periods.per_bucket(signed_up, edges)
    }
  end

  # One row per person per UTC day; a period's figure is the distinct
  # people among the rows on its dates. Buckets and the previous period
  # only count when measurement had begun by then.
  defp active_people(%{start: start, previous_start: previous_start, edges: edges}) do
    measured_from = Ash.read_one!(UsageMeasurement, authorize?: false).started_on
    since = DateTime.to_date(previous_start)
    start_day = DateTime.to_date(start)

    rows =
      ActiveDay
      |> Ash.Query.filter(day >= ^since)
      |> Ash.Query.select([:user_id, :day])
      |> Ash.read!(authorize?: false)

    {current, previous} = Enum.split_with(rows, &(Date.compare(&1.day, start_day) != :lt))

    %{
      count: distinct_people(current),
      # Collection starts partway through its first date. Only later dates
      # can begin a completely measured previous period.
      previous: if(Date.compare(since, measured_from) == :gt, do: distinct_people(previous)),
      spark:
        edges
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [from, to] -> active_in_bucket(rows, measured_from, from, to) end),
      measured_from: measured_from
    }
  end

  # A bucket runs from its first date to the date before the next edge,
  # or to today for the last one.
  defp active_in_bucket(rows, measured_from, from, to) do
    first = DateTime.to_date(from)
    last = to |> DateTime.add(-1, :second) |> DateTime.to_date()

    if measured?(measured_from, last) do
      rows
      |> Enum.filter(&(Date.compare(&1.day, first) != :lt and Date.compare(&1.day, last) != :gt))
      |> distinct_people()
    end
  end

  defp measured?(nil, _day), do: false
  defp measured?(measured_from, day), do: Date.compare(measured_from, day) != :gt

  defp distinct_people(rows), do: rows |> Enum.map(& &1.user_id) |> Enum.uniq() |> length()

  defp groups(actor) do
    Group
    |> Ash.Query.for_read(:read_with_archived, %{}, actor: actor)
    |> Ash.Query.filter(
      is_public == true or owner_id == ^actor.id or
        exists(group_members, user_id == ^actor.id and role == :organizer)
    )
    |> Ash.Query.select([:id, :name, :slug, :created_at, :archived_at])
    |> Ash.Query.load(:member_count)
    |> Ash.read!(actor: actor)
  end

  defp group_figures(groups, ended, %{start: start, now: now, edges: [_first | ends]}) do
    held_by = ended |> held_in(start, now) |> Enum.map(& &1.group_id) |> Enum.uniq()

    %{
      count: Enum.count(groups, &is_nil(&1.archived_at)),
      started: Enum.count(groups, &Periods.within?(&1.created_at, start, now)),
      held: length(held_by),
      spark: Enum.map(ends, fn at -> Enum.count(groups, &live_at?(&1, at)) end)
    }
  end

  defp live_at?(group, at) do
    DateTime.compare(group.created_at, at) != :gt and
      (is_nil(group.archived_at) or DateTime.compare(group.archived_at, at) == :gt)
  end

  # Every huddl that has ended, cancelled ones included, with the fields
  # the period figures and the group ranking need.
  defp ended_huddlz(%{now: now, actor: actor, group_ids: group_ids}) do
    Huddl
    |> Ash.Query.filter(
      group_id in ^group_ids and ends_at < ^now and
        lifecycle_state in [:published, :completed, :cancelled]
    )
    |> Ash.Query.select([
      :id,
      :group_id,
      :ends_at,
      :lifecycle_state,
      :turnout_in_room,
      :turnout_on_call,
      :turnout_recorded_at,
      :turnout_skipped_at
    ])
    |> Ash.Query.load(:rsvp_count)
    |> Ash.read!(authorize?: false, actor: actor)
  end

  defp held?(huddl), do: huddl.lifecycle_state != :cancelled

  defp held_in(ended, from, to),
    do: Enum.filter(ended, &(held?(&1) and Periods.within?(&1.ends_at, from, to)))

  defp held(ended, %{start: start, previous_start: previous_start, now: now} = window) do
    current = held_in(ended, start, now)
    cancelled = Enum.reject(ended, &held?/1)

    buckets =
      window.buckets
      |> Enum.map(fn {label, from, to} ->
        %{
          label: label,
          starts_at: from,
          ends_at: to,
          held: Enum.count(current, &Periods.within?(&1.ends_at, from, to)),
          cancelled: Enum.count(cancelled, &Periods.within?(&1.ends_at, from, to))
        }
      end)

    %{
      count: length(current),
      previous: length(held_in(ended, previous_start, start)),
      cancelled: Enum.count(cancelled, &Periods.within?(&1.ends_at, start, now)),
      unit: window.spec.growth,
      spark: Periods.per_bucket(Enum.map(current, & &1.ends_at), window.edges),
      buckets: buckets
    }
  end

  # The huddlz the administrator can see, each with its group.
  defp visible_huddlz(%{actor: actor, group_ids: group_ids}) do
    Huddl
    |> Ash.Query.filter(group_id in ^group_ids)
    |> Ash.Query.select([:id, :group_id])
    |> Ash.read!(actor: actor)
    |> Map.new(&{&1.id, &1.group_id})
  end

  # RSVPs still standing, made since the previous period began, each with
  # who made it, the huddl, and the group the huddl belongs to. A waitlist
  # spot is made when it is promoted, as on a group's overview.
  defp standing_rsvps(%{previous_start: since, huddl_ids: huddl_ids, huddl_groups: groups}) do
    {:huddlz, huddl_ids}
    |> RsvpMoment.standing_since(since)
    |> Enum.map(
      &%{
        rsvped_at: &1.at,
        user_id: &1.user_id,
        huddl_id: &1.huddl_id,
        group_id: Map.fetch!(groups, &1.huddl_id)
      }
    )
  end

  defp rsvp_figures(rsvps, %{start: start, edges: edges}) do
    {current, previous} =
      Enum.split_with(rsvps, &(DateTime.compare(&1.rsvped_at, start) != :lt))

    %{
      count: length(current),
      previous: length(previous),
      spark: Periods.per_bucket(Enum.map(current, & &1.rsvped_at), edges)
    }
  end

  defp turnout(ended, %{start: start, now: now}) do
    past = held_in(ended, start, now)
    {counted, rest} = Enum.split_with(past, &counted?/1)
    {skipped, unanswered} = Enum.split_with(rest, &(not is_nil(&1.turnout_skipped_at)))
    rsvps = counted |> Enum.map(& &1.rsvp_count) |> Enum.sum()
    came = counted |> Enum.map(&turnout_total/1) |> Enum.sum()

    %{
      past: length(past),
      counted: length(counted),
      skipped: length(skipped),
      unanswered: length(unanswered),
      rsvps: rsvps,
      turnout: came,
      show_rate: show_rate(came, rsvps),
      spark:
        counted
        |> Enum.sort_by(& &1.ends_at, DateTime)
        |> Enum.map(&show_rate(turnout_total(&1), &1.rsvp_count))
        |> Enum.reject(&is_nil/1)
    }
  end

  defp counted?(huddl), do: not is_nil(huddl.turnout_recorded_at)

  defp turnout_total(huddl), do: (huddl.turnout_in_room || 0) + (huddl.turnout_on_call || 0)

  defp show_rate(_came, 0), do: nil
  defp show_rate(came, rsvps), do: round(came * 100 / rsvps)

  # Groups ranked by the RSVPs they gathered in the period, then by the
  # huddlz they held; only groups with either make the list.
  defp active_groups(groups, ended, rsvps, %{start: start, now: now}) do
    held = ended |> held_in(start, now) |> Enum.group_by(& &1.group_id)

    rsvps_by_group =
      rsvps
      |> Enum.filter(&(DateTime.compare(&1.rsvped_at, start) != :lt))
      |> Enum.frequencies_by(& &1.group_id)

    ever_held = ended |> Enum.filter(&held?/1) |> Enum.map(& &1.group_id) |> MapSet.new()

    ranked =
      groups
      |> Enum.map(fn group ->
        huddlz = Map.get(held, group.id, [])
        counted = Enum.filter(huddlz, &counted?/1)
        counted_rsvps = counted |> Enum.map(& &1.rsvp_count) |> Enum.sum()

        %{
          id: group.id,
          name: group.name,
          slug: group.slug,
          held: length(huddlz),
          rsvps: Map.get(rsvps_by_group, group.id, 0),
          show_rate: show_rate(Enum.sum(Enum.map(counted, &turnout_total/1)), counted_rsvps),
          members: group.member_count
        }
      end)
      |> Enum.filter(&(&1.rsvps > 0 or &1.held > 0))
      |> Enum.sort_by(&{-&1.rsvps, -&1.held, String.downcase(to_string(&1.name))})

    quiet = Enum.filter(groups, &(is_nil(&1.archived_at) and not Map.has_key?(held, &1.id)))

    %{
      groups: Enum.take(ranked, @active_groups_limit),
      ranked: length(ranked),
      quiet: length(quiet),
      never_held: Enum.count(quiet, &(not MapSet.member?(ever_held, &1.id)))
    }
  end

  defp coming_up(%{now: now, actor: actor, group_ids: group_ids}) do
    until = DateTime.add(now, @coming_up_days, :day)

    upcoming =
      Huddl
      |> Ash.Query.filter(
        group_id in ^group_ids and lifecycle_state == :published and
          starts_at >= ^now and starts_at < ^until
      )
      |> Ash.Query.sort(starts_at: :asc)
      |> Ash.Query.select([:id, :title, :starts_at, :time_zone, :max_attendees, :group_id])
      |> Ash.Query.load([:rsvp_count, group: Ash.Query.select(Group, [:name, :slug])])
      |> Ash.read!(authorize?: false, actor: actor)

    %{
      days: @coming_up_days,
      count: length(upcoming),
      rsvps: upcoming |> Enum.map(& &1.rsvp_count) |> Enum.sum(),
      groups: upcoming |> Enum.map(& &1.group_id) |> Enum.uniq() |> length(),
      next:
        upcoming
        |> Enum.take(@coming_up_limit)
        |> Enum.map(fn huddl ->
          %{
            id: huddl.id,
            title: huddl.title,
            starts_at: huddl.starts_at,
            time_zone: huddl.time_zone,
            rsvp_count: huddl.rsvp_count,
            capacity: huddl.max_attendees,
            group: %{name: huddl.group.name, slug: huddl.group.slug}
          }
        end)
    }
  end
end
