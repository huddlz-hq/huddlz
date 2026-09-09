defmodule CalendarAgendaSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import PhoenixTest

  step "I am going to {string} on day {int} of next month at {string}",
       %{args: [title, day, time], current_user: attendee} = context do
    host = context[:agenda_host] || generate(user(role: :user))

    group =
      context[:agenda_group] ||
        generate(group(name: "Portland Elixir", owner_id: host.id, is_public: true, actor: host))

    {:ok, start_time} = Time.from_iso8601(time <> ":00")

    huddl =
      generate(
        huddl(
          group_id: group.id,
          creator_id: host.id,
          is_private: false,
          title: title,
          date: %{next_month() | day: day},
          start_time: start_time,
          actor: host
        )
      )

    huddl
    |> Ash.Changeset.for_update(:rsvp, %{}, actor: attendee)
    |> Ash.update!()

    context
    |> Map.put(:agenda_host, host)
    |> Map.put(:agenda_group, group)
    |> Map.update(:agenda_huddlz, [huddl], &[huddl | &1])
  end

  # One of the two always lands in the current month, whatever today's date.
  step "I have huddlz on the days either side of today", %{current_user: attendee} = context do
    host = generate(user(role: :user))
    group = generate(group(owner_id: host.id, is_public: true, actor: host))
    yesterday = DateTime.utc_now() |> DateTime.add(-1, :day) |> DateTime.truncate(:second)

    past =
      generate(
        past_huddl(
          group_id: group.id,
          creator_id: host.id,
          is_private: false,
          title: "Yesterday's huddl",
          starts_at: yesterday,
          ends_at: DateTime.add(yesterday, 1, :hour),
          actor: host
        )
      )

    upcoming =
      generate(
        huddl(
          group_id: group.id,
          creator_id: host.id,
          is_private: false,
          title: "Tomorrow's huddl",
          date: Date.add(eastern_today(), 1),
          actor: host
        )
      )

    for huddl <- [past, upcoming] do
      huddl
      |> Ash.Changeset.for_update(:rsvp, %{}, actor: attendee)
      |> Ash.update!()
    end

    context
  end

  step "I open next month's agenda", %{conn: conn} = context do
    open_agenda(context, conn, next_month())
  end

  step "I open this month's agenda", %{conn: conn} = context do
    open_agenda(context, conn, eastern_today())
  end

  step "the agenda shows day {int} with {string}",
       %{args: [day, title], session: session} = context do
    assert_has(session, "#{day_selector(day)} .cal-agenda-title", text: title)
    context
  end

  step "the agenda shows day {int} with {string} then {string}",
       %{args: [day, first, second], session: session} = context do
    titles =
      session
      |> assert_has(day_selector(day))
      |> render_titles(day_selector(day))

    assert titles == [first, second]
    context
  end

  step "each agenda huddl shows its group and my status", %{session: session} = context do
    session
    |> assert_has(".cal-agenda-entry .cal-agenda-meta", text: "Portland Elixir", count: 3)
    |> assert_has(".cal-agenda-entry .cal-entry-status[data-status=going]",
      text: "Going",
      count: 3
    )

    context
  end

  step "the agenda marks today as having nothing on", %{session: session} = context do
    session
    |> assert_has("#calendar-agenda .cal-agenda-day[data-today] .cal-agenda-day-context",
      text: "Today"
    )
    |> assert_has("#calendar-agenda .cal-agenda-day[data-today] .cal-agenda-quiet",
      text: "Nothing today"
    )

    context
  end

  defp open_agenda(context, conn, %Date{year: year, month: month}) do
    month_param = "#{year}-#{String.pad_leading(to_string(month), 2, "0")}"
    session = visit(conn, "/calendar?month=#{month_param}&view=agenda")
    Map.merge(context, %{conn: session, session: session})
  end

  defp next_month do
    today = eastern_today()
    total = today.year * 12 + today.month
    Date.new!(div(total, 12), rem(total, 12) + 1, 1)
  end

  defp day_selector(day) do
    %Date{year: year, month: month} = next_month()
    date = Date.new!(year, month, day)
    "#calendar-agenda-day-#{Date.to_iso8601(date)}"
  end

  defp render_titles(session, selector) do
    session.view
    |> Phoenix.LiveViewTest.render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query("#{selector} .cal-agenda-title")
    |> Enum.map(&(&1 |> LazyHTML.text() |> String.trim()))
  end
end
