defmodule Huddlz.Admin.PlatformStats do
  @moduledoc """
  The figures behind the admin overview, for a chosen period. Reached
  through `Huddlz.Admin.platform_overview/2`, which lets only
  administrators in; the reads here trust that boundary. The actor is
  passed along so huddl reads see everything an administrator does,
  private groups included.

  Every definition is the organizer overview's (`Huddlz.Communities.GroupStats`)
  so a number means the same thing on `/admin` and on a group's page:
  RSVPs are the rows still standing, huddlz held are published huddlz
  that ended, and the show rate is turnout divided by RSVPs across the
  counted huddlz. The platform has no single time zone, so buckets and
  "today" run on UTC days.

  People are confirmed accounts. Active people are the distinct people
  who did something the app keeps for good in the period: RSVPd or
  joined a waitlist, joined a group, created a huddl, or anything the
  group activity log recorded. Sign-ins are not kept, so they never
  count.
  """

  require Ash.Query

  alias Huddlz.Accounts.User
  alias Huddlz.Communities.{Group, GroupActivity, GroupMember, Huddl, HuddlAttendee, Periods}

  @zone "Etc/UTC"
  @coming_up_days 30
  @coming_up_limit 5
  @active_groups_limit 8

  @doc """
  Overview figures for the platform over a period.

    * `people` — confirmed accounts now, how many signed up in the period,
      and a sparkline of accounts over time
    * `active` — distinct people active in the period, the count in the
      period before, and a per-bucket sparkline
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
  """
  def compute(period, actor, now \\ DateTime.utc_now()) do
    spec = Periods.spec(period)
    {period_start, previous_start} = Periods.starts(now, spec)

    window = %{
      now: now,
      start: period_start,
      previous_start: previous_start,
      spec: spec,
      edges: Periods.bucket_edges(now, spec),
      actor: actor
    }

    ended = ended_huddlz(window)
    groups = groups()
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
      coming_up: coming_up(window)
    }
  end

  defp people(%{start: start, edges: edges}) do
    signed_up =
      User
      |> Ash.Query.filter(not is_nil(confirmed_at))
      |> Ash.Query.select([:inserted_at])
      |> Ash.read!(authorize?: false)
      |> Enum.map(& &1.inserted_at)

    %{
      count: length(signed_up),
      joined: Enum.count(signed_up, &(DateTime.compare(&1, start) != :lt)),
      spark: Periods.cumulative(signed_up, edges)
    }
  end

  # Everyone who did something since the previous period began, as
  # {person, when} pairs from every record the app keeps.
  defp active_people(%{start: start, previous_start: since, edges: edges, actor: actor}) do
    attendees =
      HuddlAttendee
      |> Ash.Query.filter(rsvped_at >= ^since)
      |> Ash.Query.select([:user_id, :rsvped_at])
      |> Ash.read!(authorize?: false)
      |> Enum.map(&{&1.user_id, &1.rsvped_at})

    joins =
      GroupMember
      |> Ash.Query.filter(created_at >= ^since)
      |> Ash.Query.select([:user_id, :created_at])
      |> Ash.read!(authorize?: false)
      |> Enum.map(&{&1.user_id, &1.created_at})

    creators =
      Huddl
      |> Ash.Query.filter(inserted_at >= ^since)
      |> Ash.Query.select([:creator_id, :inserted_at])
      |> Ash.read!(authorize?: false, actor: actor)
      |> Enum.map(&{&1.creator_id, &1.inserted_at})

    logged =
      GroupActivity
      |> Ash.Query.filter(occurred_at >= ^since)
      |> Ash.Query.select([:user_id, :occurred_at])
      |> Ash.read!(authorize?: false)
      |> Enum.map(&{&1.user_id, &1.occurred_at})

    actions = attendees ++ joins ++ creators ++ logged

    {current, previous} =
      Enum.split_with(actions, fn {_, at} -> DateTime.compare(at, start) != :lt end)

    %{
      count: distinct(current),
      previous: distinct(previous),
      spark:
        edges
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [from, to] ->
          distinct(Enum.filter(current, fn {_, at} -> Periods.within?(at, from, to) end))
        end)
    }
  end

  defp distinct(actions), do: actions |> Enum.map(&elem(&1, 0)) |> Enum.uniq() |> length()

  defp groups do
    Group
    |> Ash.Query.for_read(:read_with_archived)
    |> Ash.Query.select([:id, :name, :slug, :created_at, :archived_at])
    |> Ash.Query.load(:member_count)
    |> Ash.read!(authorize?: false)
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
  defp ended_huddlz(%{now: now, actor: actor}) do
    Huddl
    |> Ash.Query.filter(
      ends_at < ^now and lifecycle_state in [:published, :completed, :cancelled]
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
      now
      |> Periods.growth_buckets(window.spec, @zone)
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

  # RSVPs still standing, made since the previous period began, each with
  # the group its huddl belongs to.
  defp standing_rsvps(%{previous_start: since, actor: actor}) do
    HuddlAttendee
    |> Ash.Query.filter(is_nil(waitlisted_at) and rsvped_at >= ^since)
    |> Ash.Query.select([:rsvped_at])
    |> Ash.Query.load(huddl: Ash.Query.select(Huddl, [:group_id]))
    |> Ash.read!(authorize?: false, actor: actor)
    |> Enum.map(&%{rsvped_at: &1.rsvped_at, group_id: &1.huddl.group_id})
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

  defp coming_up(%{now: now, actor: actor}) do
    until = DateTime.add(now, @coming_up_days, :day)

    upcoming =
      Huddl
      |> Ash.Query.filter(
        lifecycle_state == :published and starts_at >= ^now and starts_at < ^until
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
