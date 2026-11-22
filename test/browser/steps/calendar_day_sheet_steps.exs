defmodule BrowserCalendarDaySheetSteps do
  use Cucumber.StepDefinition

  import Huddlz.Generator
  import Huddlz.Test.BrowserHelpers
  import PhoenixTest

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

    Map.merge(context, %{conn: sign_in(context.conn, attendee), huddl: huddl, day: date})
  end

  step "I have opened next month's calendar in a narrow browser", context do
    %Date{year: y, month: m} = context.day
    month = "#{y}-#{String.pad_leading(to_string(m), 2, "0")}"

    conn =
      context.conn
      |> visit("/calendar/month?month=#{month}")
      |> assert_has(".phx-connected")
      |> assert_browser("innerWidth === 320 && !document.querySelector('#calendar-day-panel')")

    Map.put(context, :conn, conn)
  end

  step "I tap the 17th", context do
    link = day_link(context.day)

    # Bring the day into the middle of the screen first, so there is a scroll
    # position to come back to.
    conn =
      assert_browser(context.conn, """
      (() => {
        const link = document.querySelector('#{link}');
        if (!link) return false;
        link.scrollIntoView({ block: 'center' });
        sessionStorage.setItem('calendar-scroll', String(Math.round(scrollY)));
        return scrollY > 0;
      })()
      """)

    Map.put(context, :conn, click_link(conn, link, "17"))
  end

  step "the day sheet is docked to the bottom edge and lists {string}",
       %{args: [title]} = context do
    conn =
      context.conn
      |> assert_has("#calendar-day-panel .cal-agenda-title", text: title)
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

    Map.put(context, :conn, conn)
  end

  step "I open {string} from the sheet and go back", %{args: [title]} = context do
    conn =
      context.conn
      |> click_link("#calendar-day-panel .cal-agenda-entry", title)
      |> assert_has("h1", text: title)
      |> assert_browser("(() => { history.back(); return true; })()")

    Map.put(context, :conn, conn)
  end

  step "the calendar returns with the sheet open on the 17th where I left it", context do
    conn =
      context.conn
      |> assert_has("#calendar-day-panel .cal-agenda-day-title",
        text: Calendar.strftime(context.day, "%B %-d")
      )
      |> assert_browser("""
      (() => {
        const expected = Number(sessionStorage.getItem('calendar-scroll'));
        return location.search.includes('day=#{Date.to_iso8601(context.day)}') &&
          document.querySelector('#month-calendar') &&
          Math.abs(scrollY - expected) < 2;
      })()
      """)

    Map.put(context, :conn, conn)
  end

  defp day_of_next_month(day) do
    today = eastern_today()
    total = today.year * 12 + today.month
    Date.new!(div(total, 12), rem(total, 12) + 1, day)
  end

  defp day_link(date), do: "#calendar-day-link-#{Date.to_iso8601(date)}"
end
