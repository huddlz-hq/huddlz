defmodule CalendarTodaySteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import Huddlz.Test.Helpers.Authentication
  import PhoenixTest

  alias Huddlz.Calendar.Clock

  step "I am signed in", %{conn: conn} = context do
    attendee = generate(user(role: :user))
    session = conn |> login(attendee) |> visit("/")

    context
    |> Map.put(:current_user, attendee)
    |> Map.put(:session, session)
  end

  step "I have a confirmed RSVP for a published huddl scheduled today",
       %{current_user: attendee} = context do
    host = generate(user(role: :user))
    group = generate(group(owner_id: host.id, is_public: true, actor: host))
    time_zone = "America/New_York"
    today = Clock.utc_now() |> DateTime.shift_zone!(time_zone) |> DateTime.to_date()
    starts_at = DateTime.new!(today, ~T[00:00:00], time_zone) |> DateTime.shift_zone!("Etc/UTC")

    huddl =
      generate(
        past_huddl(
          group_id: group.id,
          creator_id: host.id,
          title: "Today Pairing",
          starts_at: starts_at,
          ends_at: DateTime.add(starts_at, 1, :day),
          time_zone: time_zone,
          is_private: false
        )
      )

    Huddlz.Communities.rsvp_huddl!(huddl, actor: attendee)

    context
    |> Map.put(:calendar_host, host)
    |> Map.put(:calendar_group, group)
    |> Map.put(:calendar_huddl, huddl)
  end

  step "the huddl uses a saved Location named {string}",
       %{
         args: [name],
         calendar_host: host,
         calendar_group: group,
         calendar_huddl: huddl
       } = context do
    address = "500 Congress Avenue, Austin, TX"

    location =
      generate(
        group_location(
          name: name,
          address: address,
          group_id: group.id,
          actor: host
        )
      )

    updated_huddl =
      huddl
      |> Ash.Changeset.for_update(
        :update,
        %{group_location_id: location.id, physical_location: address},
        actor: host
      )
      |> Ash.update!(authorize?: false)

    context
    |> Map.put(:calendar_huddl, updated_huddl)
    |> Map.put(:calendar_location, location)
  end

  step "I am not a member of the group hosting the huddl", context do
    refute Enum.any?(
             Huddlz.Communities.get_by_user!(actor: context.current_user),
             &(&1.group_id == context.calendar_group.id)
           )

    context
  end

  step "I visit Calendar", context do
    session = visit(context[:session] || context.conn, "/calendar")

    case context[:device_time_zone] do
      nil ->
        Map.put(context, :session, session)

      time_zone ->
        Mox.allow(Huddlz.MockCalendarClock, self(), session.view.pid)

        Phoenix.LiveViewTest.render_hook(
          session.view,
          "calendar:set-time-zone",
          %{"timezone" => time_zone}
        )

        Map.put(context, :session, session)
    end
  end

  step "the current date is selected", %{session: session} = context do
    today =
      Clock.utc_now()
      |> DateTime.shift_zone!(context[:device_time_zone] || "America/New_York")
      |> DateTime.to_date()

    if PhoenixTest.Driver.current_path(session) =~ "view=month" do
      assert_has(session, "#calendar-month-day-#{Date.to_iso8601(today)}[aria-current='date']")
    else
      assert_has(session, "#calendar-view-day[aria-current='page']")
    end

    context
  end

  step "I see the huddl in chronological order",
       %{session: session, calendar_huddl: huddl} = context do
    assert_has(session, "#calendar-day-list #calendar-huddl-#{huddl.id}", text: huddl.title)
    context
  end

  step "the huddl is marked {string}",
       %{args: [marker], session: session, calendar_huddl: huddl} = context do
    assert_has(
      session,
      "#calendar-huddl-#{huddl.id} [data-testid='calendar-relationship']",
      text: marker
    )

    context
  end

  step "I see {string} on the huddl card",
       %{args: [text], session: session, calendar_huddl: huddl} = context do
    assert_has(session, "#calendar-huddl-#{huddl.id}", text: text)
    context
  end

  step "I do not see the Location's full street address on the huddl card",
       %{session: session, calendar_huddl: huddl, calendar_location: location} = context do
    refute_has(session, "#calendar-huddl-#{huddl.id}", text: location.address)
    context
  end

  step "I select the huddl card", %{session: session, calendar_huddl: huddl} = context do
    Map.put(context, :session, click_link(session, huddl.title))
  end

  step "I am taken to the huddl detail page",
       %{session: session, calendar_group: group, calendar_huddl: huddl} = context do
    assert_path(session, "/groups/#{group.slug}/huddlz/#{huddl.id}")
    context
  end
end
