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

  step "I am going to {string}, which started yesterday and is still running",
       %{args: [title]} = context do
    going_to(context, title, {24 * 60, :minute}, {60, :minute})
  end

  step "I open the week containing {string}", %{args: [title], conn: conn} = context do
    date = scheduled_date(context, title)
    session = visit(conn, "/calendar/week?week=#{date}")
    Map.merge(context, %{conn: session, session: session})
  end

  step "I open the scheduled day for {string} from the month view",
       %{args: [title], conn: conn} = context do
    date = scheduled_date(context, title)

    session =
      conn
      |> visit("/calendar/month?month=#{Calendar.strftime(date, "%Y-%m")}")
      |> click_link("#calendar-day-link-#{date}", to_string(date.day))

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

  defp starts_at({ago, unit}) do
    shift(now(), {-ago, unit})
  end

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)

  defp shift(datetime, {amount, unit}), do: DateTime.add(datetime, amount, unit)

  defp scheduled_date(context, title) do
    context.happening_huddlz
    |> Map.fetch!(title)
    |> Map.fetch!(:starts_at)
    |> DateTime.shift_zone!("America/New_York")
    |> DateTime.to_date()
  end

  defp assert_timing(context, scope, entry_prefix, title, timing) do
    %{session: session, happening_huddlz: huddlz} = context
    huddl = Map.fetch!(huddlz, title)

    assert_has(session, "#{scope} ##{entry_prefix}-#{huddl.id}", text: timing)

    context
  end
end
