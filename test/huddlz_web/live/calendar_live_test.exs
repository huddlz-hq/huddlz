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
      |> assert_has(".cal-legend", text: "Going")
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
        assert_has(session, ".cal-day-name", text: day)
      end
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
      |> assert_has(".cal-pill", text: "Going Show")
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

      filler = generate(user(role: :user))
      rsvp!(huddl, filler, :rsvp)

      huddl = Ash.reload!(huddl)
      rsvp!(huddl, attendee, :join_waitlist)

      conn
      |> login(attendee)
      |> visit(calendar_path_for(tomorrow()))
      |> assert_has(".cal-pill.tentative", text: "Sold Out")
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
      |> assert_has(".cal-pill.past", text: "Old Workshop")
    end

    test "hosting (creator) appears even without an RSVP", %{
      conn: conn,
      host: host,
      public_group: public_group
    } do
      _huddl = create_huddl(host, public_group, title: "I Am Hosting", date: tomorrow())

      conn
      |> login(host)
      |> visit(calendar_path_for(tomorrow()))
      |> assert_has(".cal-pill", text: "I Am Hosting")
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
      |> assert_has(".pill", text: "Going")
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

  defp next_month_param(date) do
    next = shift(date, 1)
    :io_lib.format("~4..0B-~2..0B", [next.year, next.month]) |> IO.iodata_to_binary()
  end

  defp shift(date, delta) do
    total = date.year * 12 + (date.month - 1) + delta
    Date.new!(div(total, 12), rem(total, 12) + 1, 1)
  end
end
