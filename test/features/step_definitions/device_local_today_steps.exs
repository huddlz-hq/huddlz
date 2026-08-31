defmodule DeviceLocalTodaySteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import Phoenix.LiveViewTest, only: [put_connect_params: 2]
  import PhoenixTest

  step "my browser time zone is {string}", %{args: [time_zone], conn: conn} = context do
    context
    |> Map.put(:device_time_zone, time_zone)
    |> Map.put(:conn, put_connect_params(conn, %{"timezone" => time_zone}))
  end

  step "I am going to a huddl whose start time falls today in {string}",
       %{args: [time_zone], current_user: attendee} = context do
    local_today = local_today(time_zone)
    starts_at = local_datetime!(local_today, ~T[17:00:00], time_zone)
    {host, group, huddl} = create_confirmed_huddl(attendee, starts_at, 60, "West Coast Today")

    context
    |> Map.put(:calendar_host, host)
    |> Map.put(:calendar_group, group)
    |> Map.put(:calendar_huddl, huddl)
  end

  step "that same instant falls tomorrow in UTC", %{calendar_huddl: huddl} = context do
    local_date = local_today(context.device_time_zone)

    assert Date.to_iso8601(DateTime.to_date(huddl.starts_at)) ==
             Date.to_iso8601(Date.add(local_date, 1))

    context
  end

  step "I am going to a huddl that starts at 11:00 PM today and ends at 1:00 AM tomorrow in my browser time zone",
       %{current_user: attendee, device_time_zone: time_zone} = context do
    local_day = ~D[2030-01-15]
    starts_at = local_datetime!(local_day, ~T[23:00:00], time_zone)
    {host, group, huddl} = create_confirmed_huddl(attendee, starts_at, 120, "Overnight Huddl")

    context
    |> Map.put(:calendar_host, host)
    |> Map.put(:calendar_group, group)
    |> Map.put(:calendar_huddl, huddl)
    |> Map.put(:before_midnight, local_datetime!(local_day, ~T[23:30:00], time_zone))
    |> Map.put(:after_midnight, local_datetime!(Date.add(local_day, 1), ~T[00:30:00], time_zone))
  end

  step "I view Day before local midnight", context do
    refresh_today_at(context, context.before_midnight)
  end

  step "I view Day after local midnight", context do
    refresh_today_at(context, context.after_midnight)
  end

  step "I went to a huddl that ended earlier today in my browser time zone",
       %{current_user: attendee, device_time_zone: time_zone} = context do
    now = DateTime.utc_now()
    local_day = now |> DateTime.shift_zone!(time_zone) |> DateTime.to_date()
    starts_at = local_datetime!(local_day, ~T[00:00:00], time_zone)
    duration_seconds = max(DateTime.diff(now, starts_at, :second) - 1, 1)

    {host, group, huddl} =
      create_confirmed_huddl(attendee, starts_at, duration_seconds, "Earlier Today", :second)

    context
    |> Map.put(:calendar_host, host)
    |> Map.put(:calendar_group, group)
    |> Map.put(:calendar_huddl, huddl)
  end

  step "the huddl has the existing past treatment", context do
    assert_has(
      context.session,
      "#calendar-huddl-#{context.calendar_huddl.id} [data-testid='calendar-relationship'].muted",
      text: "Attended · Past"
    )

    context
  end

  step "I see the huddl", context do
    assert_has(
      context.session,
      "#calendar-day-list #calendar-huddl-#{context.calendar_huddl.id}",
      text: context.calendar_huddl.title
    )

    context
  end

  defp local_today(time_zone) do
    DateTime.utc_now()
    |> DateTime.shift_zone!(time_zone)
    |> DateTime.to_date()
  end

  defp local_datetime!(date, time, time_zone) do
    date
    |> DateTime.new!(time, time_zone)
    |> DateTime.shift_zone!("Etc/UTC")
  end

  defp create_confirmed_huddl(attendee, starts_at, duration, title, unit \\ :minute) do
    host = generate(user(role: :user))
    group = generate(group(owner_id: host.id, is_public: true, actor: host))

    huddl =
      generate(
        past_huddl(
          group_id: group.id,
          creator_id: host.id,
          title: title,
          starts_at: starts_at,
          ends_at: DateTime.add(starts_at, duration, unit),
          lifecycle_state: :published,
          is_private: false
        )
      )

    Huddlz.Communities.rsvp_huddl!(huddl, actor: attendee)
    {host, group, huddl}
  end

  defp refresh_today_at(context, now) do
    Mox.expect(Huddlz.MockCalendarClock, :utc_now, fn -> now end)
    Mox.allow(Huddlz.MockCalendarClock, self(), context.session.view.pid)

    Phoenix.LiveViewTest.render_hook(
      context.session.view,
      "calendar:set-time-zone",
      %{"timezone" => context.device_time_zone}
    )

    retain_time_zone_connect_param(context)
  end

  defp retain_time_zone_connect_param(context) do
    conn = put_connect_params(context.session.conn, %{"timezone" => context.device_time_zone})
    Map.put(context, :session, %{context.session | conn: conn})
  end
end
