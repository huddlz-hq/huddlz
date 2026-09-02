defmodule CalendarMonthSteps do
  use Cucumber.StepDefinition

  import Huddlz.Test.Helpers.Calendar
  import PhoenixTest

  step "I have a Calendar huddl today", context do
    today = current_calendar_date()
    {host, group} = create_calendar_host_and_group()

    huddl =
      create_personal_calendar_huddl(
        context.current_user,
        group,
        host,
        "Today Code and Coffee",
        DateTime.new!(today, ~T[09:00:00], "Etc/UTC")
      )

    Map.merge(context, %{calendar_huddl: huddl, selected_month_day: today})
  end

  step "I select Month in Calendar", context do
    session = click_link(context.session, "#calendar-view-month", "Month")
    Map.put(context, :session, session)
  end

  step "I see a Sunday-first grid for the current month", context do
    assert_has(context.session, "#calendar-month-grid [role='columnheader']:first-child",
      text: "Sun"
    )

    assert_has(context.session, "#calendar-month-grid [role='columnheader']:last-child",
      text: "Sat"
    )

    context
  end

  step "I see today's huddl card below the grid", context do
    assert_has(
      context.session,
      "#calendar-month-day-huddlz #calendar-huddl-#{context.calendar_huddl.id}",
      text: context.calendar_huddl.title
    )

    context
  end

  step "I have four Calendar huddlz on one date", context do
    date = %{current_calendar_date() | day: 10}
    {host, group} = create_calendar_host_and_group()

    for index <- 0..3 do
      create_personal_calendar_huddl(
        context.current_user,
        group,
        host,
        "Month huddl #{index + 1}",
        DateTime.new!(date, Time.add(~T[09:00:00], index * 3600), "Etc/UTC")
      )
    end

    Map.merge(context, %{
      month_date: date,
      accessibility_month_date: date
    })
  end

  step "I open Calendar Month", context do
    path =
      case context[:month_date] do
        %Date{} = date ->
          "/calendar?view=month&month=#{Calendar.strftime(date, "%Y-%m")}&date=#{Date.to_iso8601(date)}"

        nil ->
          "/calendar?view=month"
      end

    Map.put(context, :session, visit(context.session, path))
  end

  step "the selected day is exposed to assistive technology", context do
    assert_has(context.session, "#calendar-month-grid a[aria-current='date']", count: 1)
    context
  end
end
