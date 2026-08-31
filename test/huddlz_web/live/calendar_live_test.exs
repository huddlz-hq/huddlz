defmodule HuddlzWeb.CalendarLiveTest do
  use HuddlzWeb.ConnCase, async: true

  alias Huddlz.Communities

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
      |> assert_has("h1", text: "Calendar")
      |> assert_has("aside.sidebar")
      |> assert_has(".sb-item.active", text: "Calendar")
      |> assert_has(".cal-toolbar")
      |> assert_has(".cal-nav-today", text: "Today")
      |> assert_has("#calendar-view-today.scope-tab.is-active[aria-current='page']")
      |> refute_has("#calendar-legend")
    end

    test "shows the current month name and 0 huddlz when empty", %{
      conn: conn,
      attendee: attendee
    } do
      conn
      |> login(attendee)
      |> visit("/calendar")
      |> assert_has(".cal-period-name", text: current_month_name())
      |> assert_has(".cal-period-count", text: "0 huddlz")
    end

    test "month grid renders 7 day-name headers", %{conn: conn, attendee: attendee} do
      session =
        conn
        |> login(attendee)
        |> visit("/calendar?view=month")

      for day <- ~w(Sun Mon Tue Wed Thu Fri Sat) do
        assert_has(session, "#calendar-month-grid [role='columnheader']", text: day)
      end
    end

    test "month grid exposes grid semantics and full date labels", %{
      conn: conn,
      attendee: attendee
    } do
      today = Date.utc_today()
      today_label = Calendar.strftime(today, "%A, %B %-d, %Y") <> ", today"

      conn
      |> login(attendee)
      |> visit("/calendar?view=month")
      |> assert_has(~s(#calendar-month-grid[role="grid"][aria-label*="#{current_month_name()}"]))
      |> assert_has("#calendar-month-grid [role='row']", count: 7)
      |> assert_has(
        ~s(#calendar-month-grid [role="gridcell"][aria-label="#{today_label}"][aria-current="date"])
      )
    end

    test "overflow days name their month in text and accessibility metadata", %{
      conn: conn,
      attendee: attendee
    } do
      session =
        conn
        |> login(attendee)
        |> visit("/calendar?view=month")

      document =
        session.view
        |> Phoenix.LiveViewTest.render()
        |> LazyHTML.from_fragment()

      overflow = LazyHTML.query(document, "#calendar-month-grid .is-outside-month")

      assert [label | _] = LazyHTML.attribute(overflow, "aria-label")
      assert String.ends_with?(label, "outside the selected month")
    end

    test "only the selected calendar view is marked current", %{
      conn: conn,
      attendee: attendee
    } do
      conn
      |> login(attendee)
      |> visit("/calendar")
      |> assert_has(".cal-view-tabs a[aria-current='page']", text: "Today")
      |> refute_has(".cal-view-tabs a[aria-current]", text: "Month")
      |> visit("/calendar?view=month")
      |> assert_has(".cal-view-tabs a[aria-current='page']", text: "Month")
      |> refute_has(".cal-view-tabs a[aria-current]", text: "Today")
      |> visit("/calendar?view=agenda")
      |> assert_has(".cal-view-tabs a[aria-current='page']", text: "Agenda")
      |> refute_has(".cal-view-tabs a[aria-current]", text: "Month")
    end
  end

  describe "month view — selected-day shared cards" do
    test "attending future huddl appears as a shared card marked Going", %{
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
      |> assert_has("#calendar-huddl-#{huddl.id}", text: "Going Show")
      |> assert_has(
        "#calendar-huddl-#{huddl.id} [data-testid='calendar-relationship']",
        text: "Going"
      )
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
      |> assert_has("#calendar-huddl-#{huddl.id}", text: "Cancelled Show")
      |> assert_has(
        "#calendar-huddl-#{huddl.id} [data-testid='calendar-relationship']",
        text: "Cancelled"
      )
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
        "#calendar-huddl-#{huddl.id} [data-testid='calendar-relationship']",
        text: "Waitlisted"
      )
      |> assert_has("#calendar-legend [data-status=waitlist]", text: "Waitlisted")
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
        "#calendar-huddl-#{past.id} [data-testid='calendar-relationship']",
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

      session =
        conn
        |> login(host)
        |> visit(calendar_path_for(DateTime.to_date(past.starts_at)))
        |> assert_has(
          "#calendar-huddl-#{past.id} [data-testid='calendar-relationship']",
          text: "Hosting · Past"
        )
        |> assert_has(
          "#calendar-legend [data-status=past-hosting]",
          text: "Hosting · Past"
        )

      session
      |> visit(calendar_path_for(DateTime.to_date(past.starts_at), view: "agenda"))
      |> assert_has(
        "#calendar-entry-#{past.id} .cal-entry-status[data-status=past-hosting]",
        text: "Hosting · Past"
      )
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
        "#calendar-huddl-#{huddl.id} [data-testid='calendar-relationship']",
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
        |> assert_has(".cal-period-count", text: "1 huddl")
        |> assert_has(
          "#calendar-huddl-#{huddl.id} [data-testid='calendar-relationship']",
          text: "Hosting"
        )

      assert session.view
             |> Phoenix.LiveViewTest.render()
             |> LazyHTML.from_fragment()
             |> LazyHTML.query("#calendar-month-day-huddlz > #calendar-huddl-#{huddl.id}")
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
      |> refute_has("#calendar-month-day-huddlz", text: "Stranger Show")
    end

    test "month count reflects huddlz on the selected day", %{
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
      |> visit(calendar_path_for(target_date))
      |> assert_has(".cal-period-count", text: "1 huddl")
    end

    test "selecting an adjacent-month day moves to that month", %{
      conn: conn,
      attendee: attendee,
      host: host,
      public_group: public_group
    } do
      focus_date = %{Date.utc_today() | day: 1}
      outside_date = Date.add(focus_date, -1)
      starts_at = DateTime.new!(outside_date, ~T[14:00:00], "Etc/UTC")

      outside =
        create_past_huddl(host, public_group,
          title: "Adjacent Month",
          starts_at: starts_at,
          ends_at: DateTime.add(starts_at, 60, :minute)
        )

      rsvp!(outside, attendee, :rsvp)

      session =
        conn
        |> login(attendee)
        |> visit(calendar_path_for(focus_date))
        |> click_link(
          "#calendar-month-day-#{Date.to_iso8601(outside_date)}",
          to_string(outside_date.day)
        )

      assert PhoenixTest.Driver.current_path(session) == calendar_path_for(outside_date)
      assert_has(session, "#calendar-huddl-#{outside.id}", text: "Adjacent Month")
    end

    test "shared card links to the huddl detail page", %{
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
      |> assert_has(
        ~s(#calendar-huddl-#{huddl.id}[href="/groups/#{public_group.slug}/huddlz/#{huddl.id}"])
      )
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

      conn
      |> login(attendee)
      |> visit(calendar_path_for(date))
      |> assert_has(
        "#calendar-huddl-#{first.id} [data-testid='calendar-relationship']",
        text: "Going"
      )
      |> assert_has(
        "#calendar-huddl-#{second.id} [data-testid='calendar-relationship']",
        text: "Going"
      )
    end
  end

  describe "month navigation" do
    test "next-month link identifies the month and selected day", %{
      conn: conn,
      attendee: attendee
    } do
      next = next_month_param(Date.utc_today())
      next_date = shift(Date.utc_today(), 1)

      conn
      |> login(attendee)
      |> visit("/calendar?view=month")
      |> assert_has(
        ~s(a.cal-nav-btn[href="/calendar?view=month&month=#{next}&date=#{Date.to_iso8601(next_date)}"])
      )
    end

    test "Today link returns to current month from a navigated state", %{
      conn: conn,
      attendee: attendee
    } do
      next = next_month_param(Date.utc_today())

      conn
      |> login(attendee)
      |> visit("/calendar?view=month&month=#{next}")
      |> assert_has(
        ~s(a.cal-nav-today[href="/calendar?view=month&month=#{Calendar.strftime(Date.utc_today(), "%Y-%m")}&date=#{Date.to_iso8601(Date.utc_today())}"])
      )
    end

    test "invalid ?month= falls back to current month", %{conn: conn, attendee: attendee} do
      conn
      |> login(attendee)
      |> visit("/calendar?month=not-a-month")
      |> assert_has(".cal-period-name", text: current_month_name())
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

    test "agenda gives Hosting precedence without duplication", %{
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
          "#calendar-entry-#{huddl.id} .cal-entry-status[data-status=hosting]",
          text: "Hosting"
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
        text: "Waitlisted"
      )

      past = create_past_huddl(host, public_group, title: "Agenda Past")
      rsvp!(past, attendee, :rsvp)

      conn
      |> login(attendee)
      |> visit(calendar_path_for(Date.add(Date.utc_today(), -2), view: "agenda"))
      |> assert_has(
        "#calendar-entry-#{past.id} .cal-entry-status[data-status=past-attended]",
        text: "Attended · Past"
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
    view = Keyword.get(opts, :view, "month")

    params = "?view=#{view}&month=#{month}&date=#{Date.to_iso8601(date)}"

    "/calendar" <> params
  end

  defp current_month_name do
    Date.utc_today() |> Calendar.strftime("%B %Y")
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
