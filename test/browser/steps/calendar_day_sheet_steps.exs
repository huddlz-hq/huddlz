defmodule BrowserCalendarDaySheetSteps do
  use Cucumber.StepDefinition
  use Fluffy.Assert

  import Fluffy, except: [step: 3]
  import Fluffy.Locator
  import Huddlz.Generator
  import Huddlz.Test.BrowserHelpers

  step "I am going to {string} on the 17th of next month", %{args: [title]} = context do
    attendee = generate(user(role: :user))
    host = generate(user(role: :user))
    group = generate(group(name: "Portland Elixir", owner_id: host.id, actor: host))
    date = day_of_next_month(17)

    huddl =
      generate(
        huddl(
          title: title,
          date: date,
          start_time: ~T[12:00:00],
          group_id: group.id,
          creator_id: host.id,
          is_private: false,
          actor: host
        )
      )

    Huddlz.Communities.rsvp_huddl!(huddl, actor: attendee)
    sign_in(context.session, attendee)

    %{huddl: huddl, day: date}
  end

  step "I have opened next month's calendar in a narrow browser", %{session: session} = context do
    %Date{year: y, month: m} = context.day
    month = "#{y}-#{String.pad_leading(to_string(m), 2, "0")}"

    session
    |> visit("/calendar/month?month=#{month}")
    |> assert(count(day_panel(), 0))

    assert %{width: 320} = Fluffy.Playwright.viewport_size(session)
    :ok
  end

  step "I tap the 17th", %{session: session} = context do
    link = day_link(context.day)

    # Bring the day into the middle of the screen first, so there is a scroll
    # position to come back to.
    session
    |> assert_browser("""
    (() => {
      const link = document.querySelector('#{link}');
      if (!link) return false;
      link.scrollIntoView({ block: 'center' });
      sessionStorage.setItem('calendar-scroll', String(Math.round(scrollY)));
      return scrollY > 0;
    })()
    """)
    |> click(by_css(link))

    :ok
  end

  step "the day sheet is docked to the bottom edge and lists {string}",
       %{args: [title], session: session} do
    session
    |> assert_has(entry(title))
    |> assert_browser("""
    (() => {
      const sheet = document.querySelector('#calendar-day-panel');
      if (!sheet) return false;
      const rect = sheet.getBoundingClientRect();
      return Math.abs(rect.bottom - innerHeight) < 1 &&
        rect.left === 0 && Math.abs(rect.right - innerWidth) < 1 &&
        rect.top > 0 &&
        document.documentElement.scrollWidth <= innerWidth;
    })()
    """)

    :ok
  end

  step "I open {string} from the sheet and go back", %{args: [title], session: session} do
    session
    |> click(entry(title))
    |> assert_has(by_role(:heading, level: 1, name: title))
    |> Fluffy.Playwright.go_back()

    :ok
  end

  step "the calendar returns with the sheet open on the 17th where I left it",
       %{session: session} = context do
    day = Date.to_iso8601(context.day)

    session
    |> assert(
      text(by_role(day_panel(), :heading, level: 2), Calendar.strftime(context.day, "%B %-d"))
    )
    |> assert(page_url(&(URI.decode_query(&1.query || "")["day"] == day)))
    |> assert_has(by_css("#month-calendar"))
    |> assert_browser("Math.abs(scrollY - Number(sessionStorage.getItem('calendar-scroll'))) < 2")

    :ok
  end

  defp day_panel, do: by_css("#calendar-day-panel")
  defp entry(title), do: by_role(day_panel(), :link, name: title)

  defp day_of_next_month(day) do
    today = eastern_today()
    total = today.year * 12 + today.month
    Date.new!(div(total, 12), rem(total, 12) + 1, day)
  end

  defp day_link(date), do: "#calendar-day-link-#{Date.to_iso8601(date)}"
end
