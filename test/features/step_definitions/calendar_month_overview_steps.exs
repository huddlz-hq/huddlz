defmodule CalendarMonthOverviewSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions, only: [assert: 1]
  import Huddlz.Generator
  import Huddlz.Test.Helpers.Calendar
  import PhoenixTest

  alias Huddlz.Calendar.Clock
  alias Huddlz.Communities
  alias Huddlz.Communities.HuddlAttendee

  step "I have Hosting, Going, Waitlisted, and Group opportunity huddlz on one date",
       context do
    date = current_display_date() |> shift_month(1) |> Map.put(:day, 15)
    starts_at = local_time_in_utc(date, ~T[10:00:00])
    user = context.current_user

    hosted_group = generate(group(owner_id: user.id, is_public: true, actor: user))
    hosted = create_huddl!(hosted_group, user, "Hosting indicator", starts_at)
    Communities.rsvp_huddl!(hosted, actor: user)

    attendee_host = generate(user(role: :user))

    attendee_group =
      generate(group(owner_id: attendee_host.id, is_public: true, actor: attendee_host))

    going =
      create_huddl!(
        attendee_group,
        attendee_host,
        "Going indicator",
        DateTime.add(starts_at, 1, :hour)
      )

    Communities.rsvp_huddl!(going, actor: user)

    waitlist_host = generate(user(role: :user))

    waitlist_group =
      generate(group(owner_id: waitlist_host.id, is_public: true, actor: waitlist_host))

    waitlisted =
      create_huddl!(
        waitlist_group,
        waitlist_host,
        "Waitlisted indicator",
        DateTime.add(starts_at, 2, :hour)
      )

    HuddlAttendee
    |> Ash.Changeset.for_create(
      :join_waitlist,
      %{huddl_id: waitlisted.id, user_id: user.id},
      actor: user
    )
    |> Ash.create!()

    %{owner: opportunity_host, group: opportunity_group} =
      create_calendar_member_group(member: user, group: [is_public: true])

    opportunity =
      create_huddl!(
        opportunity_group,
        opportunity_host,
        "Group opportunity indicator",
        DateTime.add(starts_at, 3, :hour)
      )

    Map.merge(context, %{
      month_date: date,
      active_month_huddlz: [hosted, going, waitlisted, opportunity]
    })
  end

  step "I have a cancelled Personal huddl on that date", context do
    host = generate(user(role: :user))
    group = generate(group(owner_id: host.id, is_public: true, actor: host))
    starts_at = local_time_in_utc(context.month_date, ~T[15:00:00])
    huddl = create_huddl!(group, host, "Cancelled Personal indicator", starts_at)
    Communities.rsvp_huddl!(huddl, actor: context.current_user)
    cancelled = Communities.cancel_huddl!(huddl, nil, actor: host)

    Map.put(context, :cancelled_month_huddl, cancelled)
  end

  step "that date shows up to three active relationship indicators", context do
    selector = month_day_selector(context.month_date)
    assert_has(context.session, "#{selector} [data-month-indicator='active']", count: 3)

    for {status, variant} <- [
          {"hosting", "magenta"},
          {"going", "cyan"},
          {"waitlisted", "amber"}
        ] do
      assert_has(
        context.session,
        "#{selector} [data-month-indicator='active'][data-status='#{status}'][data-variant='#{variant}']"
      )
    end

    context
  end

  step "it shows +N for the remaining active huddlz", context do
    assert_has(context.session, "#{month_day_selector(context.month_date)} [data-month-overflow]",
      text: "+1"
    )

    context
  end

  step "the cancelled huddl has a distinct muted indicator", context do
    assert_has(
      context.session,
      "#{month_day_selector(context.month_date)} [data-month-indicator='cancelled'][data-variant='muted']"
    )

    context
  end

  step "the cancelled huddl is excluded from +N", context do
    assert_has(context.session, "#{month_day_selector(context.month_date)} [data-month-overflow]",
      text: "+1"
    )

    context
  end

  step "the legend explains every indicator", context do
    for {status, variant} <- [
          {"hosting", "magenta"},
          {"going", "cyan"},
          {"waitlisted", "amber"},
          {"group-opportunity", "neutral"},
          {"cancelled", "muted"}
        ] do
      assert_has(
        context.session,
        "#calendar-month-legend [data-status='#{status}'][data-variant='#{variant}']"
      )
    end

    context
  end

  step "I navigated three months into the future", context do
    date = current_display_date() |> shift_month(3) |> Map.put(:day, 12)
    month = Calendar.strftime(date, "%Y-%m")

    session =
      visit(
        context.session,
        "/calendar?view=month&month=#{month}&date=#{Date.to_iso8601(%{date | day: 1})}"
      )

    Map.merge(context, %{session: session, month_date: date})
  end

  step "I have two Calendar huddlz on a date in that month", context do
    host = generate(user(role: :user))
    group = generate(group(owner_id: host.id, is_public: true, actor: host))

    morning =
      create_huddl!(
        group,
        host,
        "Future morning huddl",
        local_time_in_utc(context.month_date, ~T[09:00:00])
      )

    afternoon =
      create_huddl!(
        group,
        host,
        "Future afternoon huddl",
        local_time_in_utc(context.month_date, ~T[14:00:00])
      )

    Communities.rsvp_huddl!(morning, actor: context.current_user)
    Communities.rsvp_huddl!(afternoon, actor: context.current_user)

    Map.put(context, :month_day_huddlz, [morning, afternoon])
  end

  step "I select that date", context do
    date = context.month_date

    session =
      click_link(
        context.session,
        month_day_selector(date),
        to_string(date.day)
      )

    Map.put(context, :session, session)
  end

  step "I remain in Month", context do
    assert_has(context.session, "#calendar-view-month[aria-current='page']", text: "Month")
    context
  end

  step "the URL preserves the displayed month and selected date", context do
    date = context.month_date

    assert PhoenixTest.Driver.current_path(context.session) ==
             "/calendar?view=month&month=#{Calendar.strftime(date, "%Y-%m")}&date=#{Date.to_iso8601(date)}"

    context
  end

  step "both huddlz appear below the grid chronologically", context do
    [morning, afternoon] = context.month_day_huddlz

    assert_has(
      context.session,
      "#calendar-month-day-huddlz > #calendar-huddl-#{morning.id}:first-of-type"
    )

    assert_has(
      context.session,
      "#calendar-month-day-huddlz > #calendar-huddl-#{afternoon.id}:nth-of-type(2)"
    )

    context
  end

  step "the page moves to the selected Day contents", context do
    date = context.month_date

    assert_has(
      context.session,
      "#{month_day_selector(date)}[href$='#calendar-month-selection'][phx-click*='focus']"
    )

    assert_has(context.session, "#calendar-month-selection[tabindex='-1']")
    context
  end

  step "the full month fits without horizontal page scrolling", context do
    assert context.viewport == :narrow
    assert_has(context.session, "#calendar-month-grid[role='grid'] > [role='row']", count: 7)
    assert_has(context.session, "#calendar-month-grid [role='gridcell']", count: 42)
    context
  end

  step "each date is keyboard operable", context do
    assert_has(context.session, "#calendar-month-grid a[role='gridcell'][href]", count: 42)
    context
  end

  step "indicators and overflow have accessible text", context do
    date_selector = month_day_selector(context.accessibility_month_date)

    assert_has(
      context.session,
      "#{date_selector}[aria-label*='Going: Narrow Month huddl'][aria-label*='1 additional huddl']"
    )

    assert_has(context.session, "#{date_selector} [data-month-indicator='active']", count: 3)
    assert_has(context.session, "#{date_selector} [data-month-overflow]", text: "+1")
    assert_has(context.session, "#calendar-month-legend[aria-label='Month indicator legend']")

    assert_has(context.session, "#calendar-month-legend [data-status='overflow']",
      text: "additional"
    )

    context
  end

  step "selecting an empty date reveals the normal empty Day state", context do
    empty_date = current_display_date() |> Map.put(:day, 1)

    session =
      click_link(
        context.session,
        month_day_selector(empty_date),
        to_string(empty_date.day)
      )

    assert_has(session, "#calendar-month-day-empty", text: "Nothing on your calendar this day.")
    Map.put(context, :session, session)
  end

  defp create_huddl!(group, creator, title, starts_at) do
    generate(
      past_huddl(
        group_id: group.id,
        creator_id: creator.id,
        title: title,
        starts_at: starts_at,
        ends_at: DateTime.add(starts_at, 45, :minute),
        lifecycle_state: :published,
        is_private: false
      )
    )
  end

  defp current_display_date do
    Clock.utc_now()
    |> DateTime.shift_zone!("America/New_York")
    |> DateTime.to_date()
  end

  defp local_time_in_utc(date, time) do
    date
    |> DateTime.new!(time, "America/New_York")
    |> DateTime.shift_zone!("Etc/UTC")
  end

  defp month_day_selector(date),
    do: "#calendar-month-day-#{Date.to_iso8601(date)}"

  defp shift_month(date, delta) do
    total = date.year * 12 + date.month - 1 + delta
    Date.new!(Integer.floor_div(total, 12), Integer.mod(total, 12) + 1, 1)
  end
end
