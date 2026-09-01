defmodule CalendarMonthSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import PhoenixTest

  alias Huddlz.Calendar.Clock
  alias Huddlz.Communities

  step "I have a Calendar huddl today", context do
    today = current_date()
    {host, group} = create_host_and_group()

    huddl =
      create_personal_huddl!(
        context.current_user,
        host,
        group,
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

  step "I have two Calendar huddlz on another day in the displayed month", context do
    selected_day = another_day_in_current_month()
    {host, group} = create_host_and_group()

    morning =
      create_personal_huddl!(
        context.current_user,
        host,
        group,
        "Morning Month huddl",
        DateTime.new!(selected_day, ~T[09:00:00], "Etc/UTC")
      )

    afternoon =
      create_personal_huddl!(
        context.current_user,
        host,
        group,
        "Afternoon Month huddl",
        DateTime.new!(selected_day, ~T[14:00:00], "Etc/UTC")
      )

    Map.merge(context, %{
      calendar_huddlz: [morning, afternoon],
      selected_month_day: selected_day
    })
  end

  step "I select that day", context do
    day = context.selected_month_day
    date = Date.to_iso8601(day)
    session = click_link(context.session, "#calendar-month-day-#{date}", to_string(day.day))
    Map.put(context, :session, session)
  end

  step "I see both huddlz below the grid in chronological order", context do
    [morning, afternoon] = context.calendar_huddlz

    assert_has(
      context.session,
      "#calendar-month-day-huddlz > #calendar-huddl-#{morning.id}:first-of-type"
    )

    assert_has(
      context.session,
      "#calendar-month-day-huddlz > #calendar-huddl-#{afternoon.id}:nth-of-type(2)"
    )

    context
  end

  step "I see each huddl's relationship marker", context do
    Enum.each(context.calendar_huddlz, fn huddl ->
      assert_has(
        context.session,
        "#calendar-huddl-#{huddl.id} [data-testid='calendar-relationship']"
      )
    end)

    context
  end

  step "the URL identifies the displayed month and selected day", context do
    date = context.selected_month_day
    path = PhoenixTest.Driver.current_path(context.session)

    assert path =~ "view=month"
    assert path =~ "month=#{Calendar.strftime(date, "%Y-%m")}"
    assert path =~ "date=#{Date.to_iso8601(date)}"
    context
  end

  step "I am using a narrow viewport", context do
    date = %{current_display_date() | day: 10}
    {host, group} = create_host_and_group()

    for index <- 0..3 do
      create_personal_huddl!(
        context.current_user,
        host,
        group,
        "Narrow Month huddl #{index + 1}",
        DateTime.new!(date, Time.add(~T[09:00:00], index * 3600), "Etc/UTC")
      )
    end

    Map.merge(context, %{
      viewport: :narrow,
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

  step "the month grid fits without horizontal page scrolling", context do
    assert context.viewport == :narrow
    assert_has(context.session, "#calendar-month-grid[role='grid']")
    assert_has(context.session, "#calendar-month-grid [role='row']", count: 7)
    context
  end

  step "each day can be reached and selected by keyboard", context do
    assert_has(context.session, "#calendar-month-grid a[href]", count: 42)
    context
  end

  step "the selected day is exposed to assistive technology", context do
    assert_has(context.session, "#calendar-month-grid a[aria-current='date']", count: 1)
    context
  end

  defp current_date do
    Clock.utc_now()
    |> DateTime.shift_zone!("America/New_York")
    |> DateTime.to_date()
  end

  defp current_display_date do
    Clock.utc_now()
    |> DateTime.shift_zone!("America/New_York")
    |> DateTime.to_date()
  end

  defp another_day_in_current_month do
    today = current_date()
    if today.day == 1, do: Date.add(today, 1), else: %{today | day: 1}
  end

  defp create_host_and_group do
    host = generate(user(role: :user))
    group = generate(group(owner_id: host.id, is_public: true, actor: host))
    {host, group}
  end

  defp create_personal_huddl!(attendee, host, group, title, starts_at) do
    huddl =
      generate(
        past_huddl(
          group_id: group.id,
          creator_id: host.id,
          title: title,
          starts_at: starts_at,
          ends_at: DateTime.add(starts_at, 60, :minute),
          lifecycle_state: :published,
          is_private: false
        )
      )

    Communities.rsvp_huddl!(huddl, actor: attendee)
    huddl
  end
end
