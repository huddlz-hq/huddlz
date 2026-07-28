defmodule HuddlzWeb.CalendarLiveTest do
  use HuddlzWeb.ConnCase, async: true

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
      |> visit("/calendar")
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
      |> visit("/calendar")
      |> assert_has("h1", text: "My calendar")
      |> assert_has("aside.sidebar")
      |> assert_has(".sb-item.active", text: "My calendar")
      |> assert_has(".cal-toolbar")
      |> assert_has(".cal-nav-today", text: "Today")
      |> assert_has(".cal-view-tabs .scope-tab.is-active", text: "Month")
      |> refute_has("#calendar-legend")
    end

    test "shows the current month name and 0 huddlz when empty", %{
      conn: conn,
      attendee: attendee
    } do
      conn
      |> login(attendee)
      |> visit("/calendar")
      |> assert_has(".cal-month-name", text: current_month_name())
      |> assert_has(".cal-month-count", text: "0 huddlz")
    end

    test "month grid renders 7 day-name headers", %{conn: conn, attendee: attendee} do
      session =
        conn
        |> login(attendee)
        |> visit("/calendar")

      for day <- ~w(Sun Mon Tue Wed Thu Fri Sat) do
        assert_has(session, "#month-calendar th[scope='col']", text: day)
      end
    end

    test "month grid exposes native table semantics and full date labels", %{
      conn: conn,
      attendee: attendee
    } do
      today = Date.utc_today()
      today_label = Calendar.strftime(today, "%A, %B %-d, %Y") <> ", today"

      conn
      |> login(attendee)
      |> visit("/calendar")
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
        |> visit("/calendar")

      document =
        session.view
        |> Phoenix.LiveViewTest.render()
        |> LazyHTML.from_fragment()

      overflow = LazyHTML.query(document, "#month-calendar td.out-of-month")

      assert [label | _] = LazyHTML.attribute(overflow, "aria-label")
      assert String.ends_with?(label, "outside the selected month")
      assert overflow |> LazyHTML.query(".cal-day-context") |> Enum.any?()
    end

    test "only the selected calendar view is marked current", %{
      conn: conn,
      attendee: attendee
    } do
      conn
      |> login(attendee)
      |> visit("/calendar")
      |> assert_has(".cal-view-tabs a[aria-current='page']", text: "Month")
      |> refute_has(".cal-view-tabs a[aria-current]", text: "Agenda")
      |> visit("/calendar?view=agenda")
      |> assert_has(".cal-view-tabs a[aria-current='page']", text: "Agenda")
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

      conn
      |> login(attendee)
      |> visit(calendar_path_for(tomorrow()))
      |> assert_has(
        "#calendar-entry-#{huddl.id}.cal-pill.going[data-status=going]",
        text: "Going ·"
      )
      |> assert_has("#calendar-legend [data-status=going]", text: "Going")
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
        text: "Waitlist ·"
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
      |> visit(calendar_path_for(Date.add(Date.utc_today(), -2)))
      |> assert_has(
        "#calendar-entry-#{past.id}.cal-pill.past[data-status=past]",
        text: "Past ·"
      )
      |> assert_has("#calendar-legend [data-status=past]", text: "Past")
    end

    test "past hosted huddl link preserves hosting context", %{
      conn: conn,
      host: host,
      public_group: public_group
    } do
      past = create_past_huddl(host, public_group, title: "Hosted Retrospective")
      when_label = Calendar.strftime(past.starts_at, "%A, %B %-d, %Y at %-I:%M %p")

      conn
      |> login(host)
      |> visit(calendar_path_for(DateTime.to_date(past.starts_at)))
      |> assert_has(~s(.cal-pill[aria-label="Hosted Retrospective, Hosted, past, #{when_label}"]))
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
        text: "Hosting ·"
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
      next = shift(Date.utc_today(), 1)
      target_date = %{next | day: 15}
      huddl = create_huddl(host, public_group, title: "Counted", date: target_date)
      rsvp!(huddl, attendee, :rsvp)

      conn
      |> login(attendee)
      |> visit("/calendar?month=#{next_month_param(Date.utc_today())}")
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
      next = next_month_param(Date.utc_today())

      conn
      |> login(attendee)
      |> visit("/calendar")
      |> assert_has(~s(a.cal-nav-btn[href="/calendar?month=#{next}"]))
    end

    test "Today link returns to current month from a navigated state", %{
      conn: conn,
      attendee: attendee
    } do
      next = next_month_param(Date.utc_today())

      conn
      |> login(attendee)
      |> visit("/calendar?month=#{next}")
      |> assert_has(~s(a.cal-nav-today[href="/calendar"]))
    end

    test "invalid ?month= falls back to current month", %{conn: conn, attendee: attendee} do
      conn
      |> login(attendee)
      |> visit("/calendar?month=not-a-month")
      |> assert_has(".cal-month-name", text: current_month_name())
    end
  end

  describe "agenda view" do
    test "?view=agenda activates the Agenda tab", %{conn: conn, attendee: attendee} do
      conn
      |> login(attendee)
      |> visit("/calendar?view=agenda")
      |> assert_has(".cal-view-tabs .scope-tab.is-active", text: "Agenda")
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
      |> visit(calendar_path_for(tomorrow(), view: "agenda"))
      |> assert_has(".row .row-title", text: "Agenda Item")
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
        |> visit(calendar_path_for(tomorrow(), view: "agenda"))
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
      |> visit(calendar_path_for(tomorrow(), view: "agenda"))
      |> assert_has(
        "#calendar-entry-#{huddl.id} .cal-entry-status[data-status=hosting]",
        text: "Hosting"
      )
      |> assert_has("#calendar-legend [data-status=hosting]", text: "Hosting")
    end

    test "agenda represents waitlisted and past statuses with text", %{
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

      conn
      |> login(attendee)
      |> visit(calendar_path_for(tomorrow(), view: "agenda"))
      |> assert_has(
        "#calendar-entry-#{waitlisted.id} .cal-entry-status[data-status=waitlist]",
        text: "Waitlist"
      )

      past = create_past_huddl(host, public_group, title: "Agenda Past")
      rsvp!(past, attendee, :rsvp)

      conn
      |> login(attendee)
      |> visit(calendar_path_for(Date.add(Date.utc_today(), -2), view: "agenda"))
      |> assert_has(
        "#calendar-entry-#{past.id} .cal-entry-status[data-status=past]",
        text: "Past"
      )
    end

    test "empty agenda shows helpful copy", %{conn: conn, attendee: attendee} do
      conn
      |> login(attendee)
      |> visit("/calendar?view=agenda")
      |> assert_has("p", text: "Nothing on the calendar this month.")
    end
  end

  defp tomorrow, do: Date.add(Date.utc_today(), 1)

  # Build a /calendar URL pinned to the month containing `date`, so the focus
  # month always matches where the huddl actually lives (matters for agenda
  # filtering and for past dates that may slip outside the default grid).
  defp calendar_path_for(date, opts \\ []) do
    month = "#{date.year}-#{String.pad_leading(to_string(date.month), 2, "0")}"
    view = Keyword.get(opts, :view)

    params =
      if view, do: "?month=#{month}&view=#{view}", else: "?month=#{month}"

    "/calendar" <> params
  end

  defp current_month_name do
    Date.utc_today() |> Calendar.strftime("%B %Y")
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
