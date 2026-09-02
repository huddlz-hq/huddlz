defmodule CalendarRangeNavigationSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import Huddlz.Test.Helpers.Authentication
  import Huddlz.Test.Helpers.Calendar
  import PhoenixTest

  step "the Calendar ranges are:", %{datatable: datatable, session: session} = context do
    expected_ranges = List.flatten(datatable.raw)

    actual_ranges =
      session.view
      |> Phoenix.LiveViewTest.render()
      |> LazyHTML.from_fragment()
      |> LazyHTML.query("#calendar-range-tabs a")
      |> Enum.map(&LazyHTML.text/1)
      |> Enum.map(&String.trim/1)

    assert actual_ranges == expected_ranges
    assert_has(session, "#calendar-range-tabs a[data-phx-link-state='push']", count: 3)
    context
  end

  step "Day is active", %{session: session} = context do
    assert_has(session, "#calendar-view-day[aria-current='page']", text: "Day")
    context
  end

  step "I am viewing Calendar Day", %{conn: conn} = context do
    user = generate(user(role: :user))
    session = conn |> login(user) |> visit("/calendar")

    Map.merge(context, %{current_user: user, session: session})
  end

  step "I have a Calendar huddl tomorrow", %{current_user: user} = context do
    tomorrow = Date.add(current_calendar_date(), 1)
    group = generate(group(owner_id: user.id, is_public: true, actor: user))

    huddl =
      generate(
        huddl(
          group_id: group.id,
          creator_id: user.id,
          title: "Tomorrow's Code and Coffee",
          date: tomorrow,
          is_private: false,
          actor: user
        )
      )

    Map.merge(context, %{calendar_huddl: huddl, tomorrow: tomorrow})
  end

  step "I select the next day", %{session: session} = context do
    Map.put(context, :session, click_link(session, "#calendar-next-period", "Next day"))
  end

  step "I remain in Day", %{session: session} = context do
    assert_has(session, "#calendar-view-day[aria-current='page']", text: "Day")
    context
  end

  step "I see tomorrow's complete date and huddl count",
       %{session: session, tomorrow: tomorrow} = context do
    assert_has(session, "#calendar-day-heading", text: format_full_date(tomorrow))
    assert_has(session, "#calendar-day-count", text: "1 huddl")
    context
  end

  step "the URL identifies tomorrow", %{session: session, tomorrow: tomorrow} = context do
    assert PhoenixTest.Driver.current_path(session) == day_path(tomorrow)
    context
  end

  step "I select Today", %{session: session} = context do
    Map.put(context, :session, click_link(session, "#calendar-current-period", "Today"))
  end

  step "I return to the current date", %{session: session} = context do
    assert PhoenixTest.Driver.current_path(session) == "/calendar"
    assert_has(session, "#calendar-day-heading", text: format_full_date(current_calendar_date()))
    context
  end

  step "I am viewing a selected date in Calendar", %{conn: conn} = context do
    user = generate(user(role: :user))
    selected_date = ~D[2030-11-14]
    session = conn |> login(user) |> visit(day_path(selected_date))

    Map.merge(context, %{current_user: user, selected_date: selected_date, session: session})
  end

  step "I use the calendar control", %{session: session} = context do
    session = click_link(session, "#calendar-control", "Open Month for selected date")
    Map.put(context, :session, session)
  end

  step "Month opens focused on that date",
       %{session: session, selected_date: selected_date} = context do
    assert_has(session, "#calendar-view-month[aria-current='page']", text: "Month")

    assert_has(
      session,
      "#calendar-month-day-#{Date.to_iso8601(selected_date)}[aria-current='date']"
    )

    assert PhoenixTest.Driver.current_path(session) == month_path(selected_date)
    context
  end

  step "Day resets with Today", %{session: session, selected_date: selected_date} = context do
    session = click_link(session, "#calendar-view-day", "Day")
    assert PhoenixTest.Driver.current_path(session) == day_path(selected_date)
    assert_has(session, "#calendar-current-period", text: "Today")

    revisited_session = visit(session, PhoenixTest.Driver.current_path(session))
    assert_has(revisited_session, "#calendar-view-day[aria-current='page']")
    assert_has(revisited_session, "#calendar-day-heading", text: format_full_date(selected_date))

    Map.put(context, :session, revisited_session)
  end

  step "Week resets with This week",
       %{session: session, selected_date: selected_date} = context do
    session = click_link(session, "#calendar-view-week", "Week")
    assert PhoenixTest.Driver.current_path(session) == week_path(selected_date)
    assert_has(session, "#calendar-current-period", text: "This week")

    revisited_session = visit(session, PhoenixTest.Driver.current_path(session))
    assert_has(revisited_session, "#calendar-view-week[aria-current='page']")
    assert_has(revisited_session, "#calendar-view-day[href='#{day_path(selected_date)}']")

    Map.put(context, :session, revisited_session)
  end

  step "Month resets with This month",
       %{session: session, selected_date: selected_date} = context do
    session = click_link(session, "#calendar-view-month", "Month")
    assert PhoenixTest.Driver.current_path(session) == month_path(selected_date)

    assert_has(
      session,
      "#calendar-month-day-#{Date.to_iso8601(selected_date)}[aria-current='date']"
    )

    assert_has(session, "#calendar-current-period", text: "This month")

    revisited_session = visit(session, PhoenixTest.Driver.current_path(session))

    assert_has(
      revisited_session,
      "#calendar-month-day-#{Date.to_iso8601(selected_date)}[aria-current='date']"
    )

    Map.put(context, :session, revisited_session)
  end

  defp day_path(date), do: "/calendar?view=day&date=#{Date.to_iso8601(date)}"

  defp month_path(date) do
    month = Calendar.strftime(date, "%Y-%m")
    "/calendar?view=month&month=#{month}&date=#{Date.to_iso8601(date)}"
  end

  defp week_path(date), do: "/calendar?view=week&date=#{Date.to_iso8601(date)}"

  defp format_full_date(date), do: Calendar.strftime(date, "%A, %B %-d, %Y")
end
