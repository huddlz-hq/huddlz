defmodule HuddlzWeb.CalendarLiveTest do
  use HuddlzWeb.ConnCase, async: true

  alias Huddlz.Communities
  alias HuddlzWeb.Components.Card
  alias HuddlzWeb.Live.Helpers.HuddlCardHelpers

  setup do
    host = generate(user(role: :user))
    attendee = generate(user(role: :user))
    public_group = generate(group(is_public: true, owner_id: host.id, actor: host))

    %{host: host, attendee: attendee, public_group: public_group}
  end

  defp rsvp!(huddl, user, action) do
    huddl
    |> Ash.Changeset.for_update(action, %{}, actor: user)
    |> Ash.update!()
  end

  defp create_huddl(host, group, opts) do
    generate(
      huddl(
        Keyword.merge(
          [
            group_id: group.id,
            creator_id: host.id,
            is_private: false,
            actor: host
          ],
          opts
        )
      )
    )
  end

  defp create_past_huddl(host, group, opts) do
    generate(
      past_huddl(
        Keyword.merge(
          [
            group_id: group.id,
            creator_id: host.id,
            is_private: false,
            actor: host
          ],
          opts
        )
      )
    )
  end

  describe "anonymous access" do
    test "redirects to sign-in", %{conn: conn} do
      conn
      |> visit("/calendar/month")
      |> assert_path("/sign-in")
    end
  end

  describe "page chrome" do
    test "renders v3 sidebar with Calendar active and v3 toolbar", %{
      conn: conn,
      attendee: attendee
    } do
      conn
      |> login(attendee)
      |> visit("/calendar/month")
      |> assert_has("h1", text: "Calendar")
      |> assert_has("aside.sidebar")
      |> assert_has(".sb-item.active[aria-current='page']", text: "Calendar")
      |> refute_has(".sb-item:not(.active)[aria-current]")
      |> assert_has(".cal-toolbar")
      |> assert_has(".cal-nav-today", text: "Today")
      |> assert_has(".cal-view-tabs .scope-tab.is-active[aria-current='page']", text: "Month")
      |> refute_has(".cal-view-tabs .scope-tab:not(.is-active)[aria-current]")
      |> refute_has("#calendar-legend")
    end

    test "shows the current month name and 0 huddlz when empty", %{
      conn: conn,
      attendee: attendee
    } do
      conn
      |> login(attendee)
      |> visit("/calendar/month")
      |> assert_has(".cal-month-name", text: current_month_name())
      |> assert_has(".cal-month-count", text: "0 huddlz")
    end

    test "month grid renders 7 day-name headers", %{conn: conn, attendee: attendee} do
      session =
        conn
        |> login(attendee)
        |> visit("/calendar/month")

      for day <- ~w(Sun Mon Tue Wed Thu Fri Sat) do
        assert_has(session, "#month-calendar th[scope='col']", text: day)
      end
    end

    test "month grid exposes native table semantics and full date labels", %{
      conn: conn,
      attendee: attendee
    } do
      today = Huddlz.Generator.eastern_today()
      today_label = Calendar.strftime(today, "%A, %B %-d, %Y") <> ", today"

      conn
      |> login(attendee)
      |> visit("/calendar/month")
      |> assert_has("#month-calendar caption", text: current_month_name())
      |> assert_has("#month-calendar thead")
      |> assert_has("#month-calendar tbody tr", count: 6)
      |> assert_has(~s(#month-calendar td[aria-label="#{today_label}"][aria-current="date"]))
    end

    test "overflow days name their month in text and accessibility metadata", %{
      conn: conn,
      attendee: attendee
    } do
      session =
        conn
        |> login(attendee)
        |> visit("/calendar/month")

      document =
        session.view
        |> Phoenix.LiveViewTest.render()
        |> LazyHTML.from_fragment()

      overflow = LazyHTML.query(document, "#month-calendar td.out-of-month")

      assert [label | _] = LazyHTML.attribute(overflow, "aria-label")
      assert String.ends_with?(label, "outside the selected month")
      assert overflow |> LazyHTML.query(".cal-day-context") |> Enum.any?()
    end

    test "the week is the default view and comes first in the toggle", %{
      conn: conn,
      attendee: attendee
    } do
      conn
      |> login(attendee)
      |> visit("/calendar/week")
      |> assert_has(".cal-view-tabs .scope-tab:first-child.is-active[aria-current='page']",
        text: "Week"
      )
      |> assert_has(".cal-view-tabs .scope-tab:last-child[href='/calendar/month']",
        text: "Month"
      )
      |> assert_has(".cal-view-tabs .scope-tab.is-active[href='/calendar/week']", text: "Week")
      |> assert_has(".cal-view-tabs .scope-tab", count: 2)
      |> refute_has(".cal-view-tabs .scope-tab", text: "Agenda")
      |> refute_has("#month-calendar")
    end

    test "only the selected calendar view is marked current", %{
      conn: conn,
      attendee: attendee
    } do
      conn
      |> login(attendee)
      |> visit("/calendar/month")
      |> assert_has(".cal-view-tabs a[aria-current='page']", text: "Month")
      |> refute_has(".cal-view-tabs a[aria-current]", text: "Week")
      |> visit("/calendar/week")
      |> assert_has(".cal-view-tabs a[aria-current='page']", text: "Week")
      |> refute_has(".cal-view-tabs a[aria-current]", text: "Month")
    end
  end

  describe "month view — RSVP'd huddlz appear as cal-pills" do
    test "attending future huddl appears as a cal-pill (Going)", %{
      conn: conn,
      attendee: attendee,
      host: host,
      public_group: public_group
    } do
      huddl = create_huddl(host, public_group, title: "Going Show", date: tomorrow())
      rsvp!(huddl, attendee, :rsvp)

      time =
        huddl.starts_at
        |> DateTime.shift_zone!(huddl.time_zone)
        |> Calendar.strftime("%-I:%M %p %Z")

      tooltip_id = "calendar-entry-tooltip-#{huddl.id}"

      conn
      |> login(attendee)
      |> visit(calendar_path_for(tomorrow()))
      |> assert_has(
        "#calendar-entry-#{huddl.id}.cal-pill.going[data-status=going][aria-describedby=#{tooltip_id}]"
      )
      |> assert_has("#calendar-entry-#{huddl.id} .cal-pill-time", text: time)
      |> assert_has("#calendar-entry-#{huddl.id} .cal-pill-title", text: "Going Show")
      |> assert_has("#calendar-entry-#{huddl.id} .cal-pill-status", text: "Going")
      |> assert_has("##{tooltip_id}[role=tooltip]", text: "#{time} · Going Show · Going")
      |> assert_has("#calendar-touch-entry-#{huddl.id}", text: "Going Show")
      |> assert_has("#calendar-touch-entry-#{huddl.id}", text: "Going")
      |> assert_has("#calendar-legend [data-status=going]", text: "Going")
    end

    test "cancelled huddl remains visible with a cancelled status", %{
      conn: conn,
      attendee: attendee,
      host: host,
      public_group: public_group
    } do
      huddl = create_huddl(host, public_group, title: "Cancelled Show", date: tomorrow())
      Communities.rsvp_huddl!(huddl, actor: attendee)
      Communities.cancel_huddl!(huddl, "Venue unavailable", actor: host)

      conn
      |> login(attendee)
      |> visit(calendar_path_for(tomorrow()))
      |> assert_has("#calendar-entry-#{huddl.id}[data-status=cancelled]")
      |> assert_has("#calendar-entry-#{huddl.id} .cal-pill-status", text: "Cancelled")
      |> assert_has("#calendar-legend [data-status=cancelled]", text: "Cancelled")
    end

    test "waitlisted huddl renders the tentative variant", %{
      conn: conn,
      attendee: attendee,
      host: host,
      public_group: public_group
    } do
      huddl =
        create_huddl(host, public_group,
          title: "Sold Out",
          max_attendees: 1,
          date: tomorrow()
        )

      huddl = Ash.reload!(huddl)
      rsvp!(huddl, attendee, :join_waitlist)

      conn
      |> login(attendee)
      |> visit(calendar_path_for(tomorrow()))
      |> assert_has(
        "#calendar-entry-#{huddl.id}.cal-pill.waitlisted[data-status=waitlist]",
        text: "Waitlist"
      )
      |> assert_has("#calendar-legend [data-status=waitlist]", text: "Waitlist")
    end

    test "past attended huddl renders the past variant", %{
      conn: conn,
      attendee: attendee,
      host: host,
      public_group: public_group
    } do
      past = create_past_huddl(host, public_group, title: "Old Workshop")
      rsvp!(past, attendee, :rsvp)

      conn
      |> login(attendee)
      |> visit(calendar_path_for(Date.add(Huddlz.Generator.eastern_today(), -2)))
      |> assert_has(
        "#calendar-entry-#{past.id}.cal-pill.past[data-status=past-attended]",
        text: "Attended · Past"
      )
      |> assert_has(
        "#calendar-legend [data-status=past-attended]",
        text: "Attended · Past"
      )
    end

    test "past hosted huddl link preserves hosting context", %{
      conn: conn,
      host: host,
      public_group: public_group
    } do
      past = create_past_huddl(host, public_group, title: "Hosted Retrospective")
      local_starts_at = DateTime.shift_zone!(past.starts_at, past.time_zone)
      when_label = Calendar.strftime(local_starts_at, "%A, %B %-d, %Y at %-I:%M %p %Z")

      session =
        conn
        |> login(host)
        |> visit(calendar_path_for(DateTime.to_date(local_starts_at)))
        |> assert_has(
          ~s(#calendar-entry-#{past.id}.cal-pill[data-status=past-hosting][aria-label="Hosted Retrospective, Hosted, past, #{when_label}"]),
          text: "Hosting · Past"
        )
        |> assert_has(
          "#calendar-legend [data-status=past-hosting]",
          text: "Hosting · Past"
        )

      # The agenda starts at today, so the past hosted huddl stays in the grid.
      session
      |> visit("/agenda")
      |> refute_has("#calendar-entry-#{past.id}")
    end

    test "hosting (creator) appears even without an RSVP", %{
      conn: conn,
      host: host,
      public_group: public_group
    } do
      huddl = create_huddl(host, public_group, title: "I Am Hosting", date: tomorrow())
      rsvp!(huddl, host, :cancel_rsvp)

      conn
      |> login(host)
      |> visit(calendar_path_for(tomorrow()))
      |> assert_has(
        "#calendar-entry-#{huddl.id}.cal-pill.hosting[data-status=hosting]",
        text: "Hosting"
      )
      |> assert_has("#calendar-legend [data-status=hosting]", text: "Hosting")
    end

    test "creator RSVP does not duplicate the huddl or month count", %{
      conn: conn,
      host: host,
      public_group: public_group
    } do
      huddl = create_huddl(host, public_group, title: "Hosted and Going", date: tomorrow())
      rsvp!(huddl, host, :rsvp)

      session =
        conn
        |> login(host)
        |> visit(calendar_path_for(tomorrow()))
        |> assert_has(".cal-month-count", text: "1 huddl")
        |> assert_has(
          "#calendar-entry-#{huddl.id}[data-status=hosting-going]",
          text: "Hosting + Going"
        )

      assert session.view
             |> Phoenix.LiveViewTest.render()
             |> LazyHTML.from_fragment()
             |> LazyHTML.query(".cal-pill")
             |> Enum.count() == 1
    end

    test "does not leak another user's RSVP'd huddl", %{
      conn: conn,
      attendee: attendee,
      host: host,
      public_group: public_group
    } do
      stranger = generate(user(role: :user))
      huddl = create_huddl(host, public_group, title: "Stranger Show", date: tomorrow())
      rsvp!(huddl, stranger, :rsvp)

      conn
      |> login(attendee)
      |> visit(calendar_path_for(tomorrow()))
      |> refute_has(".cal-pill", text: "Stranger Show")
    end

    test "month count reflects huddlz in the focus month", %{
      conn: conn,
      attendee: attendee,
      host: host,
      public_group: public_group
    } do
      next = shift(Huddlz.Generator.eastern_today(), 1)
      target_date = %{next | day: 15}
      huddl = create_huddl(host, public_group, title: "Counted", date: target_date)
      rsvp!(huddl, attendee, :rsvp)

      conn
      |> login(attendee)
      |> visit("/calendar/month?month=#{next_month_param(Huddlz.Generator.eastern_today())}")
      |> assert_has(".cal-month-count", text: "1 huddl")
    end

    test "month legend includes statuses on visible adjacent-month huddlz", %{
      conn: conn,
      attendee: attendee,
      host: host,
      public_group: public_group
    } do
      focus_date = tomorrow()
      in_month = create_huddl(host, public_group, title: "In Month", date: focus_date)
      rsvp!(in_month, attendee, :rsvp)

      outside_date = calendar_grid_end(focus_date)

      outside =
        create_huddl(host, public_group,
          title: "Outside Month",
          max_attendees: 1,
          date: outside_date
        )

      outside = Ash.reload!(outside)
      rsvp!(outside, attendee, :join_waitlist)

      conn
      |> login(attendee)
      |> visit(calendar_path_for(focus_date))
      |> assert_has("#calendar-entry-#{outside.id}.out-of-month-pill[data-status=waitlist]")
      |> assert_has(
        "#calendar-touch-entry-#{outside.id}[data-status=waitlist]",
        text: "Outside Month"
      )
      |> assert_has("#calendar-legend [data-status=going]", text: "Going")
      |> assert_has("#calendar-legend [data-status=waitlist]", text: "Waitlist")
    end

    test "cal-pill links to the huddl detail page", %{
      conn: conn,
      attendee: attendee,
      host: host,
      public_group: public_group
    } do
      huddl = create_huddl(host, public_group, title: "Linked", date: tomorrow())
      rsvp!(huddl, attendee, :rsvp)

      conn
      |> login(attendee)
      |> visit(calendar_path_for(tomorrow()))
      |> assert_has(~s(.cal-pill[href="/groups/#{public_group.slug}/huddlz/#{huddl.id}"]))
    end

    test "huddl links have date, time, title, and attendance context", %{
      conn: conn,
      attendee: attendee,
      host: host,
      public_group: public_group
    } do
      date = tomorrow()
      first = create_huddl(host, public_group, title: "Morning Pairing", date: date)
      second = create_huddl(host, public_group, title: "Evening Pairing", date: date)
      rsvp!(first, attendee, :rsvp)
      rsvp!(second, attendee, :rsvp)
      full_date = Calendar.strftime(date, "%A, %B %-d, %Y")

      conn
      |> login(attendee)
      |> visit(calendar_path_for(date))
      |> assert_has(
        ~s(#month-calendar td[aria-label^="#{full_date}"] .cal-pill[aria-label^="Morning Pairing, Going, #{full_date} at "])
      )
      |> assert_has(
        ~s(#month-calendar td[aria-label^="#{full_date}"] .cal-pill[aria-label^="Evening Pairing, Going, #{full_date} at "])
      )
    end
  end

  describe "month navigation" do
    test "next-month link patches the URL with ?month=YYYY-MM", %{
      conn: conn,
      attendee: attendee
    } do
      next = next_month_param(Huddlz.Generator.eastern_today())

      conn
      |> login(attendee)
      |> visit("/calendar/month")
      |> assert_has(~s(a.cal-nav-btn[href="/calendar/month?month=#{next}"]))
    end

    test "Today link returns to current month from a navigated state", %{
      conn: conn,
      attendee: attendee
    } do
      next = next_month_param(Huddlz.Generator.eastern_today())

      conn
      |> login(attendee)
      |> visit("/calendar/month?month=#{next}")
      |> assert_has(~s(a.cal-nav-today[href="/calendar/month"]))
    end

    test "invalid ?month= falls back to current month", %{conn: conn, attendee: attendee} do
      conn
      |> login(attendee)
      |> visit("/calendar/month?month=not-a-month")
      |> assert_has(".cal-month-name", text: current_month_name())
    end
  end

  describe "agenda view" do
    test "the agenda is its own page with no view tabs", %{conn: conn, attendee: attendee} do
      conn
      |> login(attendee)
      |> visit("/agenda")
      |> assert_has("h1", text: "Agenda", exact: true)
      |> assert_has(".cal-month-name", text: "What's next")
      |> refute_has(".cal-view-tabs")
      |> refute_has(".cal-grid")
    end

    test "agenda lists RSVP'd huddlz with title and pill", %{
      conn: conn,
      attendee: attendee,
      host: host,
      public_group: public_group
    } do
      huddl = create_huddl(host, public_group, title: "Agenda Item", date: tomorrow())
      rsvp!(huddl, attendee, :rsvp)

      conn
      |> login(attendee)
      |> visit("/agenda")
      |> assert_has(".cal-agenda .cal-agenda-entry .cal-agenda-title", text: "Agenda Item")
      |> assert_has("#calendar-entry-#{huddl.id}.cal-agenda-entry .cal-agenda-time")
      |> assert_has(
        "#calendar-entry-#{huddl.id} .cal-entry-status[data-status=going]",
        text: "Going"
      )
    end

    test "agenda uses the same combined Hosting + Going status without duplication", %{
      conn: conn,
      host: host,
      public_group: public_group
    } do
      huddl = create_huddl(host, public_group, title: "Hosted Agenda", date: tomorrow())

      session =
        conn
        |> login(host)
        |> visit("/agenda")
        |> assert_has(
          "#calendar-entry-#{huddl.id} .cal-entry-status[data-status=hosting-going]",
          text: "Hosting + Going"
        )

      assert session.view
             |> Phoenix.LiveViewTest.render()
             |> LazyHTML.from_fragment()
             |> LazyHTML.query("#calendar-entry-#{huddl.id}")
             |> Enum.count() == 1
    end

    test "agenda represents hosting without attendance", %{
      conn: conn,
      host: host,
      public_group: public_group
    } do
      huddl = create_huddl(host, public_group, title: "Hosting Agenda", date: tomorrow())
      rsvp!(huddl, host, :cancel_rsvp)

      conn
      |> login(host)
      |> visit("/agenda")
      |> assert_has(
        "#calendar-entry-#{huddl.id} .cal-entry-status[data-status=hosting]",
        text: "Hosting"
      )
      |> assert_has("#calendar-legend [data-status=hosting]", text: "Hosting")
    end

    test "agenda represents waitlisted with text and leaves the past to the month view", %{
      conn: conn,
      attendee: attendee,
      host: host,
      public_group: public_group
    } do
      waitlisted =
        create_huddl(host, public_group,
          title: "Agenda Waitlist",
          max_attendees: 1,
          date: tomorrow()
        )

      waitlisted = Ash.reload!(waitlisted)
      rsvp!(waitlisted, attendee, :join_waitlist)
      past = create_past_huddl(host, public_group, title: "Agenda Past")
      rsvp!(past, attendee, :rsvp)

      conn
      |> login(attendee)
      |> visit("/agenda")
      |> assert_has(
        "#calendar-entry-#{waitlisted.id} .cal-entry-status[data-status=waitlist]",
        text: "Waitlist"
      )
      |> refute_has("#calendar-entry-#{past.id}")
      |> refute_has("#calendar-legend [data-status=past-attended]")
    end

    test "an agenda with nothing coming up says so quietly", %{
      conn: conn,
      host: host,
      attendee: attendee,
      public_group: public_group
    } do
      past = create_past_huddl(host, public_group, title: "Old Workshop")
      rsvp!(past, attendee, :rsvp)

      conn
      |> login(attendee)
      |> visit("/agenda")
      |> assert_has("#calendar-agenda-empty.empty-state h3", text: "Nothing coming up")
      |> assert_has("#calendar-agenda-empty p", text: "Your next RSVP will land here.")
      |> assert_has("#calendar-agenda-empty a.btn-secondary[href='/discover']",
        text: "Browse huddlz"
      )
      |> refute_has(".cal-agenda")
      |> refute_has("#calendar-first-run")
    end

    test "a first run explains the agenda and the calendar", %{conn: conn, attendee: attendee} do
      session =
        conn
        |> login(attendee)
        |> visit("/agenda")
        |> assert_has("#calendar-first-run.empty-state h3", text: "Nothing on your agenda yet")
        |> assert_has("#calendar-first-run p",
          text: "huddlz you RSVP to show up here, soonest first."
        )
        |> assert_has("#calendar-first-run a.btn-primary[href='/discover']", text: "Find a huddl")
        |> refute_has("#calendar-agenda-empty")

      session
      |> visit("/calendar/month")
      |> assert_has("#month-calendar")
      |> assert_has("#calendar-first-run.empty-state h3", text: "Your calendar is empty")
    end

    test "today is drawn as the anchor even with nothing on", %{
      conn: conn,
      attendee: attendee,
      host: host,
      public_group: public_group
    } do
      next = create_huddl(host, public_group, title: "Next Thing", date: tomorrow())
      rsvp!(next, attendee, :rsvp)

      conn
      |> login(attendee)
      |> visit("/agenda")
      |> assert_has("#calendar-agenda .cal-agenda-day[data-today] .cal-agenda-day-context",
        text: "Today"
      )
      |> assert_has("#calendar-agenda .cal-agenda-day[data-today] .cal-agenda-quiet",
        text: "Nothing today."
      )
      |> refute_has("#calendar-agenda .cal-agenda-day[data-today] a")
    end

    test "a cancelled huddl stays on its day with a cancelled pill and no countdown", %{
      conn: conn,
      attendee: attendee,
      host: host,
      public_group: public_group
    } do
      huddl = create_huddl(host, public_group, title: "Called Off", date: tomorrow())
      rsvp!(huddl, attendee, :rsvp)
      Communities.cancel_huddl!(huddl, "Venue unavailable", actor: host)

      conn
      |> login(attendee)
      |> visit("/agenda")
      |> assert_has("#calendar-entry-#{huddl.id} .cal-agenda-title", text: "Called Off")
      |> assert_has("#calendar-entry-#{huddl.id} .cal-entry-status[data-status=cancelled]",
        text: "Cancelled"
      )
      |> refute_has("#calendar-entry-#{huddl.id} .cal-agenda-relative")
    end

    test "the agenda ignores the month param and shows what's next", %{
      conn: conn,
      attendee: attendee,
      host: host,
      public_group: public_group
    } do
      soon = create_huddl(host, public_group, title: "Soon Enough", date: tomorrow())
      rsvp!(soon, attendee, :rsvp)
      far = Date.add(Huddlz.Generator.eastern_today(), 400)

      conn
      |> login(attendee)
      |> visit("/agenda?month=#{Calendar.strftime(far, "%Y-%m")}")
      |> assert_has(".cal-month-name", text: "What's next")
      |> assert_has(".cal-month-count", text: "1 huddl")
      |> refute_has(".cal-nav")
      |> assert_has("#calendar-entry-#{soon.id} .cal-agenda-title", text: "Soon Enough")
      |> refute_has("#calendar-agenda-more")
    end

    test "the agenda stops after seven days with huddlz and points at the month view", %{
      conn: conn,
      attendee: attendee,
      host: host,
      public_group: public_group
    } do
      today = Huddlz.Generator.eastern_today()

      huddlz =
        for offset <- [1, 1, 2, 3, 5, 8, 13, 21, 34] do
          huddl =
            create_huddl(host, public_group,
              title: "Day #{offset}",
              date: Date.add(today, offset)
            )

          rsvp!(huddl, attendee, :rsvp)
          huddl
        end

      # Eight distinct days; the window keeps the first seven and points at
      # the month holding the eighth.
      beyond = List.last(huddlz)
      eighth = Date.add(today, 34)

      conn
      |> login(attendee)
      |> visit("/agenda")
      |> assert_has("#calendar-agenda .cal-agenda-entry", count: 8)
      |> assert_has(".cal-month-count", text: "8 huddlz")
      |> refute_has("#calendar-entry-#{beyond.id}")
      |> assert_has("#calendar-agenda-more a[href='#{calendar_path_for(eighth)}']",
        text: "Open #{Calendar.strftime(eighth, "%B %Y")} in the month view"
      )
    end

    test "past days in the touch list go quiet and drop the countdown", %{
      conn: conn,
      attendee: attendee,
      host: host,
      public_group: public_group
    } do
      past = create_past_huddl(host, public_group, title: "Agenda Gone By")
      rsvp!(past, attendee, :rsvp)
      day = DateTime.to_date(HuddlCardHelpers.local_starts_at(past))

      conn
      |> login(attendee)
      |> visit(calendar_path_for(day))
      |> assert_has(
        "#calendar-touch-agenda-list-day-#{Date.to_iso8601(day)}[data-past] .cal-agenda-title",
        text: "Agenda Gone By"
      )
      |> refute_has("#calendar-touch-entry-#{past.id} .cal-agenda-relative")
    end

    test "an entry shows the group's initials, its place and how far off it is", %{
      conn: conn,
      attendee: attendee,
      host: host,
      public_group: public_group
    } do
      {date, start_time} = thirty_hours_out()

      in_person =
        create_huddl(host, public_group, title: "Somewhere", date: date, start_time: start_time)

      online =
        create_huddl(host, public_group,
          title: "Nowhere",
          date: date,
          start_time: start_time,
          event_type: :virtual,
          virtual_link: "https://meet.example.com/nowhere"
        )

      rsvp!(in_person, attendee, :rsvp)
      rsvp!(online, attendee, :rsvp)

      conn
      |> login(attendee)
      |> visit("/agenda")
      |> assert_has("#calendar-entry-#{in_person.id} .cal-agenda-thumb .card-cover-fallback span",
        text: Card.group_initials(public_group.name)
      )
      |> assert_has("#calendar-entry-#{in_person.id} .cal-agenda-meta",
        text: in_person.physical_location
      )
      |> assert_has("#calendar-entry-#{online.id} .cal-agenda-meta", text: "Online")
      |> assert_has("#calendar-entry-#{in_person.id} .cal-agenda-relative", text: "tomorrow")
    end

    test "the touch list under the month grid uses the same day groups", %{
      conn: conn,
      attendee: attendee,
      host: host,
      public_group: public_group
    } do
      huddl = create_huddl(host, public_group, title: "Touch Me", date: tomorrow())
      rsvp!(huddl, attendee, :rsvp)
      day = Date.to_iso8601(DateTime.to_date(HuddlCardHelpers.local_starts_at(huddl)))

      conn
      |> login(attendee)
      |> visit(calendar_path_for(tomorrow()))
      |> assert_has("#calendar-touch-agenda-list-day-#{day} .cal-agenda-daynum")
      |> assert_has("#calendar-touch-entry-#{huddl.id}.cal-agenda-entry .cal-agenda-title",
        text: "Touch Me"
      )
      |> refute_has("#calendar-touch-agenda-list .cal-agenda-day[data-today] .cal-agenda-quiet")
    end
  end

  describe "scope: my RSVPs or my groups" do
    setup %{attendee: attendee, host: host, public_group: public_group} do
      generate(group_member(group_id: public_group.id, user_id: attendee.id, actor: host))
      %{}
    end

    test "the chips carry upcoming counts and default to my RSVPs", %{
      conn: conn,
      attendee: attendee,
      host: host,
      public_group: public_group
    } do
      mine = create_huddl(host, public_group, title: "Mine", date: tomorrow())
      rsvp!(mine, attendee, :rsvp)
      create_huddl(host, public_group, title: "Theirs", date: Date.add(tomorrow(), 1))

      # The agenda counts from today onward, whatever weekday the suite runs
      # on; the week window is covered with pinned dates in the scope feature.
      conn
      |> login(attendee)
      |> visit("/agenda")
      |> assert_has("#calendar-scope-mine.chip.is-active[aria-current='page']", text: "RSVPs")
      |> assert_has("#calendar-scope-mine .chip-count", text: "1")
      |> assert_has(
        "#calendar-scope-groups.chip:not(.is-active)[href='/agenda?scope=groups']",
        text: "Groups"
      )
      |> assert_has("#calendar-scope-groups .chip-count", text: "2")
      |> refute_has(".cal-agenda-title", text: "Theirs")
    end

    test "my groups adds unanswered huddlz with an outlined pill in the grid and a legend entry",
         %{conn: conn, attendee: attendee, host: host, public_group: public_group} do
      {date, start_time} = thirty_hours_out()

      theirs =
        create_huddl(host, public_group, title: "Theirs", date: date, start_time: start_time)

      conn
      |> login(attendee)
      |> visit(calendar_path_for(tomorrow()) <> "&scope=groups")
      |> assert_has("#calendar-entry-#{theirs.id}.cal-pill.open[data-status=open]",
        text: "Theirs"
      )
      |> assert_has("#calendar-legend [data-status=open] .cal-legend-swatch.outline")
      |> assert_has("#calendar-legend [data-status=open]", text: "No RSVP")
      |> assert_has("#calendar-scope-groups.chip.is-active")
    end

    test "the scope survives switching views and paging months", %{
      conn: conn,
      attendee: attendee
    } do
      next = next_month_param(Huddlz.Generator.eastern_today())

      conn
      |> login(attendee)
      |> visit("/calendar/week?scope=groups")
      |> assert_has("#calendar-view-month[href='/calendar/month?scope=groups']")
      |> visit("/calendar/month?scope=groups")
      |> assert_has("#calendar-view-week[href='/calendar/week?scope=groups']")
      |> assert_has(~s(a.cal-nav-btn[href="/calendar/month?month=#{next}&scope=groups"]))
      |> assert_has("#calendar-scope-mine[href='/calendar/month']")
    end

    test "my groups leaves out the past and cancelled huddlz nobody answered", %{
      conn: conn,
      attendee: attendee,
      host: host,
      public_group: public_group
    } do
      gone = create_past_huddl(host, public_group, title: "Missed It")
      off = create_huddl(host, public_group, title: "Called Off", date: tomorrow())
      Communities.cancel_huddl!(off, "Venue unavailable", actor: host)
      answered = create_huddl(host, public_group, title: "Answered", date: tomorrow())
      Communities.cancel_huddl!(answered, "Venue unavailable", actor: host)
      rsvp_before_cancel = create_huddl(host, public_group, title: "Was Going", date: tomorrow())
      rsvp!(rsvp_before_cancel, attendee, :rsvp)
      Communities.cancel_huddl!(rsvp_before_cancel, "Venue unavailable", actor: host)
      gone_day = DateTime.to_date(HuddlCardHelpers.local_starts_at(gone))

      conn
      |> login(attendee)
      |> visit("/calendar/week?scope=groups")
      |> refute_has("#calendar-entry-#{off.id}")
      |> refute_has("#calendar-entry-#{answered.id}")
      |> assert_has("#calendar-entry-#{rsvp_before_cancel.id} [data-status=cancelled]")
      |> visit(calendar_path_for(gone_day) <> "&scope=groups")
      |> refute_has("#calendar-entry-#{gone.id}")
    end

    test "a newcomer's groups still show what they have on", %{
      conn: conn,
      attendee: attendee,
      host: host,
      public_group: public_group
    } do
      {date, start_time} = thirty_hours_out()

      theirs =
        create_huddl(host, public_group, title: "Theirs", date: date, start_time: start_time)

      conn
      |> login(attendee)
      |> visit("/agenda")
      |> assert_has("#calendar-first-run")
      |> visit("/agenda?scope=groups")
      |> refute_has("#calendar-first-run")
      |> assert_has("#calendar-entry-#{theirs.id} .cal-agenda-title", text: "Theirs")
      |> refute_has("#calendar-entry-#{theirs.id} .cal-entry-status")
      |> assert_has("#calendar-entry-#{theirs.id} .cal-agenda-relative", text: "tomorrow")
    end
  end

  describe "week view" do
    test "the Week tab opens this week from this month and the first week of another month", %{
      conn: conn,
      attendee: attendee
    } do
      today = Huddlz.Generator.eastern_today()
      next = shift(today, 1)
      first_week = Date.beginning_of_week(next, :sunday)

      conn
      |> login(attendee)
      |> visit("/calendar/month")
      |> assert_has("#calendar-view-week[href='/calendar/week']", text: "Week")
      |> visit("/calendar/month?month=#{next_month_param(today)}")
      |> assert_has("#calendar-view-week[href='/calendar/week?week=#{first_week}']")
    end

    test "draws every day of the week, blank where nothing is on, and today says so", %{
      conn: conn,
      attendee: attendee
    } do
      today = Huddlz.Generator.eastern_today()
      start = Date.beginning_of_week(today, :sunday)

      session =
        conn
        |> login(attendee)
        |> visit("/calendar/week")
        |> assert_has(".cal-view-tabs .scope-tab.is-active[aria-current='page']", text: "Week")
        |> assert_has(".cal-month-name", text: Calendar.strftime(start, "%b %-d"))
        |> assert_has(".cal-month-count", text: "0 huddlz")
        |> assert_has("#calendar-week .cal-agenda-day", count: 7)
        |> assert_has("#calendar-week .cal-agenda-day[data-blank]", count: 6)
        |> assert_has("#calendar-week .cal-agenda-day[data-today] .cal-agenda-quiet",
          text: "Nothing today."
        )
        |> refute_has("#calendar-week .cal-agenda-day[data-blank] .cal-agenda-quiet")
        |> refute_has("#calendar-legend")

      for offset <- 0..6 do
        assert_has(session, "#calendar-week-day-#{Date.add(start, offset)}")
      end
    end

    test "any date names its week, the rail marks a month change, and nonsense means this week",
         %{conn: conn, attendee: attendee} do
      this_week = Date.beginning_of_week(Huddlz.Generator.eastern_today(), :sunday)

      conn
      |> login(attendee)
      |> visit("/calendar/week?week=2030-10-02")
      |> assert_has(".cal-month-name", text: "Sep 29 – Oct 5, 2030")
      |> assert_has("#calendar-week-day-2030-09-29")
      |> assert_has("#calendar-week-day-2030-10-01 .cal-agenda-day-context", text: "Oct")
      |> refute_has("#calendar-week-day-2030-09-30 .cal-agenda-day-context")
      |> assert_has("a.cal-nav-btn[href='/calendar/week?week=2030-09-22']",
        text: "Previous week"
      )
      |> assert_has("a.cal-nav-btn[href='/calendar/week?week=2030-10-06']",
        text: "Next week"
      )
      |> assert_has("a.cal-nav-today[href='/calendar/week']", text: "Today")
      |> assert_has("#calendar-view-month[href='/calendar/month?month=2030-09']")
      |> visit("/calendar/week?week=someday")
      |> assert_has("#calendar-week-day-#{this_week}")
      |> assert_has("a.cal-nav-today[href='/calendar/week']")
    end

    test "lists the week's huddlz with the legend for them and keeps the scope", %{
      conn: conn,
      host: host,
      attendee: attendee,
      public_group: group
    } do
      in_week = ~D[2030-10-02]
      hosted = create_huddl(host, group, title: "In the week", date: in_week)
      rsvp!(hosted, attendee, :rsvp)
      after_week = create_huddl(host, group, title: "The week after", date: ~D[2030-10-09])
      rsvp!(after_week, attendee, :rsvp)

      conn
      |> login(attendee)
      |> visit("/calendar/week?week=2030-09-29&scope=groups")
      |> assert_has("#calendar-week-day-2030-10-02 .cal-agenda-title", text: "In the week")
      |> refute_has("#calendar-week .cal-agenda-title", text: "The week after")
      |> assert_has(".cal-month-count", text: "1 huddl")
      |> assert_has("#calendar-legend .cal-legend-item", count: 1)
      |> assert_has("a.cal-nav-btn[href='/calendar/week?week=2030-10-06&scope=groups']")
      |> assert_has("#calendar-scope-mine[href='/calendar/week?week=2030-09-29']")
    end
  end

  describe "day panel" do
    test "opens from a day number with that day's huddlz and closes back to the month", %{
      conn: conn,
      host: host,
      attendee: attendee,
      public_group: group
    } do
      day = ~D[2030-10-17]
      huddl = create_huddl(host, group, title: "Elixir office hours", date: day)
      rsvp!(huddl, attendee, :rsvp)
      other = create_huddl(host, group, title: "The day before", date: ~D[2030-10-16])
      rsvp!(other, attendee, :rsvp)

      conn
      |> login(attendee)
      |> visit("/calendar/month?month=2030-10")
      |> refute_has("#calendar-day-panel")
      |> assert_has(
        "#calendar-day-link-2030-10-17[href='/calendar/month?month=2030-10&day=2030-10-17']"
      )
      |> click_link("#calendar-day-link-2030-10-17", "17")
      |> assert_has("td.cal-cell.is-open #calendar-day-link-2030-10-17")
      |> assert_has("#calendar-day-panel[role=dialog][aria-modal=true]")
      |> assert_has("#calendar-day-panel .cal-day-kicker", text: "Thursday")
      |> assert_has("#calendar-day-panel-title", text: "October 17")
      |> assert_has("#calendar-day-panel .cal-day-count", text: "1 huddl")
      |> assert_has("#calendar-day-entry-#{huddl.id} .cal-agenda-title",
        text: "Elixir office hours"
      )
      |> refute_has("#calendar-day-panel .cal-agenda-title", text: "The day before")
      |> assert_has("#calendar-day-week[href='/calendar/week?week=2030-10-13']",
        text: "Open this week"
      )
      |> assert_has("#calendar-day-layer[phx-key=escape]")
      |> click_link("#calendar-day-close", "Close")
      |> assert_path("/calendar/month", query_params: %{"month" => "2030-10"})
      |> refute_has("#calendar-day-panel")
      |> refute_has("td.cal-cell.is-open")
    end

    test "an empty day says so and the scope survives opening it", %{
      conn: conn,
      attendee: attendee
    } do
      conn
      |> login(attendee)
      |> visit("/calendar/month?month=2030-10&scope=groups&day=2030-10-03")
      |> assert_has("#calendar-day-panel .cal-agenda-quiet", text: "Nothing on this day.")
      |> assert_has("#calendar-day-panel .cal-day-count", text: "0 huddlz")
      |> assert_has("#calendar-day-close[href='/calendar/month?month=2030-10&scope=groups']")
      |> visit("/calendar/month?month=2030-10&day=not-a-day")
      |> refute_has("#calendar-day-panel")
    end

    test "marks today in the panel", %{conn: conn, attendee: attendee} do
      today = Huddlz.Generator.eastern_today()

      conn
      |> login(attendee)
      |> visit("/calendar/month?day=#{today}")
      |> assert_has("#calendar-day-panel[data-today] .cal-day-kicker-today", text: "Today")
    end
  end

  defp tomorrow, do: Date.add(Huddlz.Generator.eastern_today(), 1)

  # A start that reads as "tomorrow" (24 to 48 hours away) whatever the
  # time of day the suite runs, as a date and time in the huddl's zone.
  defp thirty_hours_out do
    local =
      DateTime.utc_now() |> DateTime.add(30, :hour) |> DateTime.shift_zone!("America/New_York")

    {DateTime.to_date(local), local |> DateTime.to_time() |> Time.truncate(:second)}
  end

  # Build a /calendar URL pinned to the month containing `date`, so the focus
  # month always matches where the huddl actually lives (matters for agenda
  # filtering and for past dates that may slip outside the default grid).
  defp calendar_path_for(date, opts \\ []) do
    month = "#{date.year}-#{String.pad_leading(to_string(date.month), 2, "0")}"
    view = Keyword.get(opts, :view, "month")

    "/calendar/#{view}?month=#{month}"
  end

  defp current_month_name do
    Huddlz.Generator.eastern_today() |> Calendar.strftime("%B %Y")
  end

  defp calendar_grid_end(date) do
    month_first = %{date | day: 1}
    offset = rem(Date.day_of_week(month_first), 7)

    month_first
    |> Date.add(-offset)
    |> Date.add(41)
  end

  defp next_month_param(date) do
    next = shift(date, 1)
    :io_lib.format("~4..0B-~2..0B", [next.year, next.month]) |> IO.iodata_to_binary()
  end

  defp shift(date, delta) do
    total = date.year * 12 + (date.month - 1) + delta
    Date.new!(div(total, 12), rem(total, 12) + 1, 1)
  end
end
