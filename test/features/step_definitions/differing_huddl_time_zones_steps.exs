defmodule DifferingHuddlTimeZonesSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import Huddlz.Test.Helpers.Authentication
  import PhoenixTest

  alias Huddlz.Accounts

  step "my Calendar time zone is {string}", %{args: [display_time_zone], conn: conn} = context do
    attendee = generate(user(role: :user))

    attendee =
      Accounts.update_display_time_zone!(attendee, :fixed, display_time_zone, actor: attendee)

    context
    |> Map.put(:current_user, attendee)
    |> Map.put(:display_time_zone, display_time_zone)
    |> Map.put(:conn, login(conn, attendee))
  end

  step "I am going to a huddl at 9:00 PM in {string}",
       %{args: [huddl_time_zone], current_user: attendee} = context do
    host = generate(user(role: :user))
    group = generate(group(owner_id: host.id, is_public: true, actor: host))
    huddl_local_date = ~D[2030-07-15]

    huddl =
      generate(
        huddl(
          group_id: group.id,
          creator_id: host.id,
          actor: host,
          title: "Pacific Evening Huddl",
          date: huddl_local_date,
          start_time: ~T[21:00:00],
          duration_minutes: 90,
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
    |> Map.put(:huddl_time_zone, huddl_time_zone)
    |> Map.put(:huddl_local_date, huddl_local_date)
  end

  step "that instant falls on a different date in New York", context do
    new_york_date =
      context.calendar_huddl.starts_at
      |> DateTime.shift_zone!("America/New_York")
      |> DateTime.to_date()

    assert new_york_date == ~D[2030-07-16]
    assert new_york_date != context.huddl_local_date
    Map.put(context, :display_date, new_york_date)
  end

  step "I view the huddl in Calendar", context do
    path = "/calendar?view=day&date=#{Date.to_iso8601(context.display_date)}"
    Map.put(context, :session, visit(context.conn, path))
  end

  step "it appears on its New York date", context do
    context.session
    |> assert_has("#calendar-day-heading", text: "Tuesday, July 16, 2030")
    |> assert_has(
      "#calendar-day-list #calendar-huddl-#{context.calendar_huddl.id}",
      text: context.calendar_huddl.title
    )

    context
  end

  step "the card's primary date and time use {string}", %{args: [time_zone]} = context do
    assert time_zone == context.display_time_zone

    context.session
    |> assert_has(
      "#calendar-huddl-#{context.calendar_huddl.id} .date-stamp .m",
      text: "JUL"
    )
    |> assert_has(
      "#calendar-huddl-#{context.calendar_huddl.id} .date-stamp .d",
      text: "16"
    )
    |> assert_has(
      "#calendar-huddl-#{context.calendar_huddl.id} [data-testid='huddl-when']",
      text: "Tue · 12:00 AM EDT"
    )

    context
  end

  step "the card identifies 9:00 PM at the huddl", context do
    assert_has(
      context.session,
      "#calendar-huddl-#{context.calendar_huddl.id} [data-testid='huddl-local-when']",
      text: "9:00 PM PDT at the huddl"
    )

    context
  end

  step "the detailed view presents only the authoritative huddl time", context do
    session =
      click_link(
        context.session,
        "#calendar-huddl-#{context.calendar_huddl.id}",
        context.calendar_huddl.title
      )

    session
    |> assert_has(
      "[data-testid='huddl-authoritative-when'][data-time-zone='America/Los_Angeles']",
      text: "Mon, Jul 15 · 9:00 PM – 10:30 PM PDT"
    )
    |> assert_has(".huddl-hero .meta", text: "Mon, Jul 15 · 9:00 PM")
    |> refute_has("[data-testid='huddl-local-when']")
    |> refute_has(".huddl-hero .meta", text: "Tue, Jul 16 · 12:00 AM")

    Map.put(context, :session, session)
  end

  step "my Calendar and Huddl time zones are both {string}",
       %{args: [time_zone], conn: conn} = context do
    attendee = generate(user(role: :user))
    attendee = Accounts.update_display_time_zone!(attendee, :fixed, time_zone, actor: attendee)
    host = generate(user(role: :user))
    group = generate(group(owner_id: host.id, is_public: true, actor: host))

    huddl =
      generate(
        huddl(
          group_id: group.id,
          creator_id: host.id,
          actor: host,
          title: "Eastern Morning Huddl",
          date: ~D[2030-07-16],
          start_time: ~T[09:00:00],
          duration_minutes: 60,
          time_zone: time_zone,
          lifecycle_state: :published,
          is_private: false
        )
      )

    context
    |> Map.put(:current_user, attendee)
    |> Map.put(:calendar_group, group)
    |> Map.put(:calendar_huddl, huddl)
    |> Map.put(:conn, login(conn, attendee))
  end

  step "I view the huddl", context do
    path = "/groups/#{context.calendar_group.slug}/huddlz/#{context.calendar_huddl.id}"
    Map.put(context, :session, visit(context.conn, path))
  end

  step "I see one schedule time", context do
    context.session
    |> assert_has("[data-testid='huddl-authoritative-when']", text: "9:00 AM – 10:00 AM EDT")
    |> refute_has("[data-testid='huddl-local-when']")

    context
  end

  step "I explicitly selected a future date and month", %{conn: conn} = context do
    explicit_user = automatic_user()
    implicit_user = automatic_user()
    calendar_now = ~U[2030-07-16 04:30:00Z]
    selected_date = ~D[2030-10-20]

    month_conn =
      conn
      |> Phoenix.LiveViewTest.put_connect_params(%{"timezone" => "America/New_York"})
      |> login(explicit_user)

    implicit_day_conn =
      conn
      |> Phoenix.LiveViewTest.put_connect_params(%{"timezone" => "America/New_York"})
      |> login(implicit_user)

    Mox.stub(Huddlz.MockCalendarClock, :utc_now, fn -> calendar_now end)

    month_session =
      visit(
        month_conn,
        "/calendar?view=month&month=2030-10&date=#{Date.to_iso8601(selected_date)}"
      )

    implicit_day_session = visit(implicit_day_conn, "/calendar")

    month_session
    |> assert_has("#calendar-month-heading", text: "October 2030")
    |> assert_has("#calendar-month-day-2030-10-20[aria-current='date']")

    assert_has(implicit_day_session, "#calendar-day-heading", text: "Tuesday, July 16, 2030")

    context
    |> Map.put(:explicit_user, explicit_user)
    |> Map.put(:implicit_user, implicit_user)
    |> Map.put(:month_session, month_session)
    |> Map.put(:implicit_day_session, implicit_day_session)
  end

  step "I change my Calendar time zone", context do
    Mox.allow(Huddlz.MockCalendarClock, self(), context.month_session.view.pid)
    Mox.allow(Huddlz.MockCalendarClock, self(), context.implicit_day_session.view.pid)

    month_session =
      select(context.month_session, "Calendar time zone", option: "America/Los_Angeles")

    implicit_day_session =
      select(context.implicit_day_session, "Calendar time zone", option: "America/Los_Angeles")

    explicit_user = Accounts.get_by_email!(context.explicit_user.email)
    implicit_user = Accounts.get_by_email!(context.implicit_user.email)

    assert explicit_user.display_time_zone_mode == :fixed
    assert explicit_user.fixed_display_time_zone == "America/Los_Angeles"
    assert implicit_user.display_time_zone_mode == :fixed
    assert implicit_user.fixed_display_time_zone == "America/Los_Angeles"

    context
    |> Map.put(:month_session, month_session)
    |> Map.put(:implicit_day_session, implicit_day_session)
  end

  step "the selected date and month remain selected", context do
    context.month_session
    |> assert_path("/calendar",
      query_params: %{"view" => "month", "month" => "2030-10", "date" => "2030-10-20"}
    )
    |> assert_has("#calendar-month-heading", text: "October 2030")
    |> assert_has("#calendar-month-day-2030-10-20[aria-current='date']")

    context
  end

  step "an implicit current Day follows today in the new time zone", context do
    context.implicit_day_session
    |> assert_path("/calendar")
    |> assert_has("#calendar-time-zone[data-time-zone='America/Los_Angeles']")
    |> assert_has("#calendar-day-heading", text: "Monday, July 15, 2030")

    context
  end

  defp automatic_user do
    user = generate(user(role: :user))
    Accounts.update_display_time_zone!(user, :automatic, nil, actor: user)
  end
end
