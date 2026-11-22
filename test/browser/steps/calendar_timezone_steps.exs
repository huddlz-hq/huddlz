defmodule BrowserCalendarSteps do
  use Cucumber.StepDefinition

  import Huddlz.Generator
  import Huddlz.Test.BrowserHelpers
  import PhoenixTest

  step "I attend a Denver huddl late on July 15", context do
    attendee = generate(user(role: :user))
    host = generate(user(role: :user))
    group = generate(group(owner_id: host.id, actor: host))

    venue =
      generate(
        group_location(
          name: "Denver Library",
          address: "10 W. Fourteenth Ave, Denver, CO, USA",
          latitude: 39.7392,
          longitude: -104.9903,
          time_zone: "America/Denver",
          group_id: group.id,
          actor: host
        )
      )

    huddl =
      generate(
        huddl(
          title: "Late Denver huddl",
          date: ~D[2030-07-15],
          start_time: ~T[23:30:00],
          duration_minutes: 60,
          group_location_id: venue.id,
          group_id: group.id,
          creator_id: host.id,
          actor: host
        )
      )

    Huddlz.Communities.rsvp_huddl!(huddl, actor: attendee)
    Map.merge(context, %{conn: sign_in(context.conn, attendee), huddl: huddl})
  end

  step "I open Calendar in a New York browser", context do
    conn =
      context.conn
      |> visit("/calendar/month?month=2030-07")
      |> assert_has(".phx-connected")
      |> assert_browser("Intl.DateTimeFormat().resolvedOptions().timeZone === 'America/New_York'")

    Map.put(context, :conn, conn)
  end

  step "the huddl appears on July 16 with its Denver local time", context do
    context.conn
    |> assert_has("#calendar-time-zone", text: "America/New_York")
    |> assert_has(
      "td[aria-label^='Tuesday, July 16, 2030'] #calendar-entry-#{context.huddl.id} .cal-pill-time",
      text: "11:30 PM MDT"
    )

    context
  end
end
