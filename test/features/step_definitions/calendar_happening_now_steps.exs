defmodule CalendarHappeningNowSteps do
  use Cucumber.StepDefinition

  import Huddlz.Generator
  import PhoenixTest

  step "I am going to {string}, which started {int} minutes ago and runs for another {int} minutes",
       %{args: [title, ago, remaining]} = context do
    going_to(context, title, {ago, :minute}, {remaining, :minute})
  end

  step "I am going to {string}, which started {int} hours ago and runs for another {int} hours",
       %{args: [title, ago, remaining]} = context do
    going_to(context, title, {ago * 60, :minute}, {remaining * 60, :minute})
  end

  step "I am going to {string}, which starts in {int} minutes",
       %{args: [title, ahead]} = context do
    going_to(context, title, {-ahead, :minute}, {ahead + 60, :minute})
  end

  step "I open this week", %{conn: conn} = context do
    session = visit(conn, "/calendar/week")
    Map.merge(context, %{conn: session, session: session})
  end

  step "I open today from the month view", %{conn: conn} = context do
    today = eastern_today()

    session =
      conn
      |> visit("/calendar/month")
      |> click_link("#calendar-day-link-#{Date.to_iso8601(today)}", to_string(today.day))

    Map.merge(context, %{conn: session, session: session})
  end

  step "the agenda times {string} as {string}", %{args: [title, timing]} = context do
    assert_timing(context, "#calendar-agenda", "calendar-entry", title, timing)
  end

  step "the week times {string} as {string}", %{args: [title, timing]} = context do
    assert_timing(context, "#calendar-week", "calendar-entry", title, timing)
  end

  step "the day panel times {string} as {string}", %{args: [title, timing]} = context do
    assert_timing(context, "#calendar-day-panel", "calendar-day-entry", title, timing)
  end

  # Seeds a huddl the current user is going to, `starts_ago` before now and
  # running until `runs_more` after it. Seeded rather than created, because the
  # create action refuses a start time in the past.
  defp going_to(%{current_user: attendee} = context, title, starts_ago, runs_more) do
    host = context[:happening_host] || generate(user(role: :user))

    group =
      context[:happening_group] ||
        generate(group(name: "Portland Elixir", owner_id: host.id, is_public: true, actor: host))

    huddl =
      generate(
        past_huddl(
          group_id: group.id,
          creator_id: host.id,
          is_private: false,
          title: title,
          starts_at: starts_at(starts_ago),
          ends_at: shift(now(), runs_more)
        )
      )

    huddl
    |> Ash.Changeset.for_update(:rsvp, %{}, actor: attendee)
    |> Ash.update!()

    context
    |> Map.put(:happening_host, host)
    |> Map.put(:happening_group, group)
    |> Map.update(:happening_huddlz, %{title => huddl}, &Map.put(&1, title, huddl))
  end

  # The agenda and the calendar place a huddl on the local day it starts, so a
  # start time is never wound back past midnight — whatever the hour the suite
  # runs at, the huddl stays on today and stays under way.
  defp starts_at({ago, unit}) do
    Enum.max([shift(now(), {-ago, unit}), start_of_local_day()], DateTime)
  end

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)

  defp shift(datetime, {amount, unit}), do: DateTime.add(datetime, amount, unit)

  defp start_of_local_day do
    eastern_today()
    |> DateTime.new!(~T[00:00:00], "America/New_York")
    |> DateTime.shift_zone!("Etc/UTC")
  end

  defp assert_timing(context, scope, entry_prefix, title, timing) do
    %{session: session, happening_huddlz: huddlz} = context
    huddl = Map.fetch!(huddlz, title)

    assert_has(session, "#{scope} ##{entry_prefix}-#{huddl.id} .cal-agenda-relative",
      text: timing,
      exact: true
    )

    context
  end
end
