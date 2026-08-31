defmodule DifferingHuddlTimeZonesSteps do
  use Cucumber.StepDefinition

  import Huddlz.Generator
  import PhoenixTest, only: [assert_has: 3]

  step "I am going to a huddl scheduled for 9:00 AM in {string}",
       %{args: [huddl_time_zone], current_user: attendee, device_time_zone: device_time_zone} =
         context do
    host = generate(user(role: :user))
    group = generate(group(owner_id: host.id, is_public: true, actor: host))
    calendar_now = ~U[2030-07-15 16:00:00Z]
    device_today = calendar_now |> DateTime.shift_zone!(device_time_zone) |> DateTime.to_date()

    huddl =
      generate(
        huddl(
          group_id: group.id,
          creator_id: host.id,
          actor: host,
          title: "Pacific Morning Huddl",
          date: device_today,
          start_time: ~T[09:00:00],
          duration_minutes: 60,
          time_zone: huddl_time_zone,
          lifecycle_state: :published,
          is_private: false
        )
      )

    Huddlz.Communities.rsvp_huddl!(huddl, actor: attendee)

    context
    |> Map.put(:calendar_host, host)
    |> Map.put(:calendar_group, group)
    |> Map.put(:calendar_huddl, huddl)
    |> Map.put(:calendar_now, calendar_now)
  end

  step "I view the huddl in Calendar", %{session: session} = context do
    Mox.expect(Huddlz.MockCalendarClock, :utc_now, fn -> context.calendar_now end)
    Mox.allow(Huddlz.MockCalendarClock, self(), session.view.pid)

    Phoenix.LiveViewTest.render_hook(
      session.view,
      "calendar:set-time-zone",
      %{"timezone" => context.device_time_zone}
    )

    context
  end

  step "the huddl is placed on the correct day in my device time zone", context do
    assert_has(
      context.session,
      "#calendar-today-list #calendar-huddl-#{context.calendar_huddl.id}",
      text: context.calendar_huddl.title
    )

    context
  end

  step "the card identifies the huddl's local time as {string}",
       %{args: [local_time]} = context do
    assert_has(
      context.session,
      "#calendar-huddl-#{context.calendar_huddl.id} [data-testid='huddl-when']",
      text: local_time
    )

    context
  end
end
