defmodule BrowserCalendarSteps do
  use Cucumber.StepDefinition
  use Fluffy.Assert

  import Fluffy, except: [step: 3]
  import Fluffy.Locator
  import Huddlz.Generator
  import Huddlz.Test.BrowserHelpers

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
    sign_in(context.session, attendee)
    %{huddl: huddl}
  end

  step "I open Calendar in a New York browser", %{session: session} do
    session
    |> visit("/calendar/month?month=2030-07")
    |> assert_browser("Intl.DateTimeFormat().resolvedOptions().timeZone === 'America/New_York'")

    :ok
  end

  step "the huddl appears on July 16 with its Denver local time", %{session: session} = context do
    day = by_css("td[aria-label^='Tuesday, July 16, 2030']")

    session
    |> assert(text(by_css("#calendar-time-zone"), "America/New_York"))
    |> assert_has(
      by_css(day, "#calendar-entry-#{context.huddl.id} .cal-pill-time")
      |> filter(has_text: "11:30 PM MDT")
    )

    :ok
  end
end
