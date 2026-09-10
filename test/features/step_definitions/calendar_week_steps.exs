defmodule CalendarWeekSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import PhoenixTest

  step "I open the week of day {int} of next month", %{args: [day], conn: conn} = context do
    week = day |> next_month_date() |> Date.beginning_of_week(:sunday)
    session = visit(conn, "/calendar/week?week=#{Date.to_iso8601(week)}")
    Map.merge(context, %{conn: session, session: session, week_start: week})
  end

  step "every day of that week is drawn", %{session: session, week_start: start} = context do
    session = assert_has(session, "#calendar-week .cal-agenda-day", count: 7)

    for offset <- 0..6 do
      date = Date.add(start, offset)
      assert_has(session, "#calendar-week-day-#{Date.to_iso8601(date)} .cal-agenda-daynum")
    end

    context
  end

  step "the week shows {string} on day {int}",
       %{args: [title, day], session: session} = context do
    date = next_month_date(day)

    assert_has(session, "#calendar-week-day-#{Date.to_iso8601(date)} .cal-agenda-title",
      text: title
    )

    context
  end

  step "the week does not list {string}", %{args: [title], session: session} = context do
    refute_has(session, "#calendar-week .cal-agenda-title", text: title)
    context
  end

  step "I move to the next week", %{session: session} = context do
    session = click_link(session, ".cal-nav-btn", "Next week")
    Map.merge(context, %{conn: session, session: session})
  end

  step "I open next month in the month view", %{conn: conn} = context do
    session = visit(conn, "/calendar/month?month=#{month_param()}")
    Map.merge(context, %{conn: session, session: session})
  end

  step "I open day {int}", %{args: [day], session: session} = context do
    session = click_link(session, day_link_selector(day), to_string(day))
    Map.merge(context, %{conn: session, session: session})
  end

  step "the day panel lists {string} then {string} with their times and places",
       %{args: [first, second], session: session} = context do
    session = assert_has(session, "#calendar-day-panel")

    assert render_texts(session, "#calendar-day-panel .cal-agenda-title") == [first, second]

    assert [noon, evening] = render_texts(session, "#calendar-day-panel .cal-agenda-time")
    assert String.starts_with?(noon, "12:00 PM")
    assert String.starts_with?(evening, "6:30 PM")

    session
    |> assert_has("#calendar-day-panel .cal-agenda-meta", text: "Portland Elixir", count: 2)
    |> assert_has("#calendar-day-panel .cal-agenda-day-title", text: day_heading(17))

    context
  end

  step "the day panel does not list {string}", %{args: [title], session: session} = context do
    refute_has(session, "#calendar-day-panel .cal-agenda-title", text: title)
    context
  end

  step "I open {string} from the day panel", %{args: [title], session: session} = context do
    session = click_link(session, "#calendar-day-panel .cal-agenda-entry", title)
    Map.merge(context, %{conn: session, session: session})
  end

  step "I am on the huddl page for {string}", %{args: [title], session: session} = context do
    assert_has(session, "h1", text: title)
    context
  end

  step "the open day is part of the address", %{session: session} = context do
    assert_path(session, "/calendar/month",
      query_params: %{
        "month" => month_param(),
        "day" => Date.to_iso8601(next_month_date(17))
      }
    )

    context
  end

  step "I close the day panel", %{session: session} = context do
    session = click_link(session, "#calendar-day-close", "Close")
    Map.merge(context, %{conn: session, session: session})
  end

  step "I am back on next month in the month view with no day open",
       %{session: session} = context do
    session
    |> assert_path("/calendar/month", query_params: %{"month" => month_param()})
    |> refute_has("#calendar-day-panel")
    |> assert_has("#month-calendar")

    context
  end

  defp next_month do
    today = eastern_today()
    total = today.year * 12 + today.month
    Date.new!(div(total, 12), rem(total, 12) + 1, 1)
  end

  defp next_month_date(day), do: %{next_month() | day: day}

  defp month_param do
    %Date{year: y, month: m} = next_month()
    "#{y}-#{String.pad_leading(to_string(m), 2, "0")}"
  end

  defp day_link_selector(day), do: "#calendar-day-link-#{Date.to_iso8601(next_month_date(day))}"

  defp day_heading(day), do: Calendar.strftime(next_month_date(day), "%B %-d")

  defp render_texts(session, selector) do
    session.view
    |> Phoenix.LiveViewTest.render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query(selector)
    |> Enum.map(&(&1 |> LazyHTML.text() |> String.trim()))
  end
end
