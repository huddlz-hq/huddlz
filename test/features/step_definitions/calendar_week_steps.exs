defmodule CalendarWeekSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import PhoenixTest

  alias Huddlz.Calendar.Clock
  alias Huddlz.Communities

  step "I have Calendar huddlz on the Sunday and Saturday of the current week", context do
    week_start = current_week_start(context.device_time_zone)

    {host, group} = create_host_and_group()

    sunday_huddl =
      create_personal_huddl!(
        context.current_user,
        host,
        group,
        "Sunday Code and Coffee",
        local_datetime!(week_start, ~T[09:00:00], context.device_time_zone),
        60
      )

    saturday_huddl =
      create_personal_huddl!(
        context.current_user,
        host,
        group,
        "Saturday Code and Coffee",
        local_datetime!(Date.add(week_start, 6), ~T[09:00:00], context.device_time_zone),
        60
      )

    Map.merge(context, %{
      calendar_huddlz: [sunday_huddl, saturday_huddl],
      expected_week_start: week_start,
      expected_week_end: Date.add(week_start, 6)
    })
  end

  step "I select Week in Calendar", context do
    session = click_link(context.session, "#calendar-view-week", "Week")
    Map.put(context, :session, session)
  end

  step "the displayed week begins Sunday and ends Saturday in my browser time zone", context do
    assert Date.day_of_week(context.expected_week_start) == 7
    assert Date.day_of_week(context.expected_week_end) == 6

    assert_has(
      context.session,
      "#calendar-week-range",
      text:
        "Week from #{format_full_date(context.expected_week_start)} through #{format_full_date(context.expected_week_end)}"
    )

    context
  end

  step "I see both huddlz in chronological order", context do
    [sunday_huddl, saturday_huddl] = context.calendar_huddlz

    assert_has(
      context.session,
      "#calendar-week-list > #calendar-huddl-#{sunday_huddl.id}:first-child"
    )

    assert_has(
      context.session,
      "#calendar-week-list > #calendar-huddl-#{saturday_huddl.id}:nth-child(2)"
    )

    context
  end

  step "I have a Calendar huddl that starts before the current week and ends during the current week",
       context do
    week_start = current_week_start(context.device_time_zone)
    {host, group} = create_host_and_group()
    starts_at = local_datetime!(Date.add(week_start, -1), ~T[23:00:00], context.device_time_zone)

    huddl =
      create_personal_huddl!(
        context.current_user,
        host,
        group,
        "Boundary-spanning huddl",
        starts_at,
        120
      )

    Map.merge(context, %{
      calendar_huddl: huddl,
      expected_week_start: week_start,
      expected_week_end: Date.add(week_start, 6)
    })
  end

  step "I see its relationship marker", context do
    assert_has(
      context.session,
      "#calendar-huddl-#{context.calendar_huddl.id} [data-testid='calendar-relationship']"
    )

    context
  end

  step "I open Calendar Week for a specific week", context do
    week_start = ~D[2030-02-10]
    path = "/calendar?view=week&date=#{Date.to_iso8601(week_start)}"

    context
    |> Map.put(:session, visit(context.session, path))
    |> Map.put(:expected_week_start, week_start)
    |> Map.put(:expected_week_end, Date.add(week_start, 6))
  end

  step "I copy and revisit the current URL", context do
    copied_url = PhoenixTest.Driver.current_path(context.session)

    context
    |> Map.put(:copied_calendar_url, copied_url)
    |> Map.put(:session, visit(context.session, copied_url))
  end

  step "Calendar shows the same week", context do
    assert_has(
      context.session,
      "#calendar-week-range",
      text:
        "Week from #{format_full_date(context.expected_week_start)} through #{format_full_date(context.expected_week_end)}"
    )

    assert PhoenixTest.Driver.current_path(context.session) == context.copied_calendar_url
    context
  end

  step "Week remains selected", context do
    assert_has(context.session, "#calendar-view-week[aria-current='page']")
    context
  end

  defp current_week_start(time_zone) do
    today =
      Clock.utc_now()
      |> DateTime.shift_zone!(time_zone)
      |> DateTime.to_date()

    Date.add(today, -rem(Date.day_of_week(today), 7))
  end

  defp local_datetime!(date, time, time_zone) do
    date
    |> DateTime.new!(time, time_zone)
    |> DateTime.shift_zone!("Etc/UTC")
  end

  defp format_full_date(date), do: Calendar.strftime(date, "%A, %B %-d, %Y")

  defp create_host_and_group do
    host = generate(user(role: :user))
    group = generate(group(owner_id: host.id, is_public: true, actor: host))
    {host, group}
  end

  defp create_personal_huddl!(attendee, host, group, title, starts_at, duration_minutes) do
    huddl =
      generate(
        past_huddl(
          group_id: group.id,
          creator_id: host.id,
          title: title,
          starts_at: starts_at,
          ends_at: DateTime.add(starts_at, duration_minutes, :minute),
          lifecycle_state: :published,
          is_private: false
        )
      )

    Communities.rsvp_huddl!(huddl, actor: attendee)
    huddl
  end
end
