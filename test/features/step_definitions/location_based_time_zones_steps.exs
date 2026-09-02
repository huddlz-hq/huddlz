defmodule LocationBasedTimeZonesSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import Huddlz.Test.Helpers.LocationSelection, only: [select_location: 2]
  import Huddlz.Test.Helpers.Authentication, only: [login: 2]
  import PhoenixTest

  require Ash.Query

  step "my group {string} is based in {string}",
       %{args: [group_name, time_zone]} = context do
    owner = context.current_user

    group = create_saint_augustine_group(owner, group_name, time_zone)

    Map.put(context, :groups, [group])
  end

  step "I select {string} as the group city in {string}",
       %{args: [display_text, time_zone]} = context do
    session = context[:session] || context[:conn]
    {latitude, longitude} = group_city_coordinates(display_text)

    session =
      select_location(session,
        id: "group-location",
        display_text: display_text,
        main_text: display_text |> String.split(",") |> List.first(),
        latitude: latitude,
        longitude: longitude,
        time_zone: time_zone
      )

    Map.merge(context, %{session: session, conn: session})
  end

  step "the group {string} should use {string}",
       %{args: [group_name, time_zone]} = context do
    group =
      Huddlz.Communities.Group
      |> Ash.Query.filter(name == ^group_name)
      |> Ash.read_one!(authorize?: false)

    assert group.time_zone == time_zone
    context
  end

  step "the group {string} should not exist", %{args: [group_name]} = context do
    group =
      Huddlz.Communities.Group
      |> Ash.Query.filter(name == ^group_name)
      |> Ash.read_one!(authorize?: false)

    assert is_nil(group)
    context
  end

  step "I try to create the group {string} with an unresolved home location",
       %{args: [group_name]} = context do
    Mox.stub(Huddlz.MockGeocoding, :geocode, fn _address -> {:error, :not_found} end)

    result =
      Huddlz.Communities.Group
      |> Ash.Changeset.for_create(
        :create_group,
        %{
          name: group_name,
          description: "A group whose location lookup failed",
          location: "Unknown Place",
          time_zone: "America/New_York",
          is_public: true
        },
        actor: context.current_user
      )
      |> Ash.create()

    Map.put(context, :unresolved_group_result, result)
  end

  step "I should be told that the group location must be resolved", context do
    assert {:error, error} = context.unresolved_group_result
    assert Exception.message(error) =~ "attribute latitude is required"
    assert Exception.message(error) =~ "attribute longitude is required"
    context
  end

  step "the huddl {string} should be at {int}:{int} {word} in {string}",
       %{args: [title, hour, minute, meridiem, time_zone]} = context do
    huddl =
      Huddlz.Communities.Huddl
      |> Ash.Query.filter(title == ^title)
      |> Ash.read_one!(authorize?: false)

    assert huddl.time_zone == time_zone

    local_time =
      huddl.starts_at
      |> DateTime.shift_zone!(time_zone)
      |> Calendar.strftime("%-I:%M %p")

    expected_time =
      "#{hour}:#{minute |> Integer.to_string() |> String.pad_leading(2, "0")} #{meridiem}"

    assert local_time == expected_time

    context
  end

  step "the group has a saved venue {string} in {string}",
       %{args: [name, time_zone]} = context do
    group = List.first(context.groups)

    location =
      generate(
        group_location(
          group_id: group.id,
          name: name,
          address: "10 W. Fourteenth Ave, Denver, CO, USA",
          latitude: 39.7392,
          longitude: -104.9903,
          time_zone: time_zone,
          actor: context.current_user
        )
      )

    Map.put(context, :group_locations, [location])
  end

  step "I try to schedule a physical huddl with a saved location that no longer exists",
       context do
    group = List.first(context.groups)

    result =
      Huddlz.Communities.Huddl
      |> Ash.Changeset.for_create(
        :create,
        %{
          title: "Missing Location Huddl",
          description: "This saved location was removed",
          event_type: :in_person,
          group_location_id: Ash.UUID.generate(),
          date: ~D[2030-07-15],
          start_time: ~T[09:00:00],
          duration_minutes: 60,
          group_id: group.id
        },
        actor: context.current_user
      )
      |> Ash.create()

    Map.put(context, :missing_saved_location_result, result)
  end

  step "I should be told that the saved location is unavailable", context do
    assert {:error, error} = context.missing_saved_location_result
    assert Exception.message(error) =~ "saved location is unavailable"
    context
  end

  step "I try to schedule a physical huddl without choosing an address book location",
       context do
    group = List.first(context.groups)

    result =
      Huddlz.Communities.Huddl
      |> Ash.Changeset.for_create(
        :create,
        %{
          title: "No Location Huddl",
          description: "No address book location was chosen",
          event_type: :in_person,
          date: ~D[2030-07-15],
          start_time: ~T[09:00:00],
          duration_minutes: 60,
          group_id: group.id
        },
        actor: context.current_user
      )
      |> Ash.create()

    Map.put(context, :no_location_result, result)
  end

  step "I should be told that an address book location is required", context do
    assert {:error, error} = context.no_location_result
    assert Exception.message(error) =~ "is required for in-person and hybrid huddlz"
    context
  end

  step "my group has a virtual huddl at 9:00 AM in {string}",
       %{args: [time_zone]} = context do
    owner = context.current_user

    group = create_saint_augustine_group(owner, "Traveling Neighbors", time_zone)

    huddl =
      generate(
        huddl(
          title: "Existing Virtual Huddl",
          date: ~D[2030-07-15],
          start_time: ~T[09:00:00],
          duration_minutes: 60,
          event_type: :virtual,
          virtual_link: "https://example.com/existing",
          group_id: group.id,
          creator_id: owner.id,
          actor: owner
        )
      )

    Map.merge(context, %{groups: [group], existing_virtual_huddl: huddl})
  end

  step "I move the group to {string}", %{args: [time_zone]} = context do
    group = List.first(context.groups)

    updated_group =
      group
      |> Ash.Changeset.for_update(:update_details, %{
        location: "Denver, CO, USA",
        latitude: 39.7392,
        longitude: -104.9903,
        time_zone: time_zone
      })
      |> Ash.update!(actor: context.current_user)

    Map.put(context, :groups, [updated_group])
  end

  step "the existing virtual huddl remains at 9:00 AM in {string}",
       %{args: [time_zone]} = context do
    huddl =
      Ash.get!(Huddlz.Communities.Huddl, context.existing_virtual_huddl.id, authorize?: false)

    assert huddl.time_zone == time_zone
    assert DateTime.shift_zone!(huddl.starts_at, time_zone).hour == 9
    context
  end

  step "a new virtual huddl uses {string}", %{args: [time_zone]} = context do
    owner = context.current_user
    group = List.first(context.groups)

    huddl =
      generate(
        huddl(
          title: "New Virtual Huddl",
          date: ~D[2030-07-16],
          start_time: ~T[09:00:00],
          duration_minutes: 60,
          event_type: :virtual,
          virtual_link: "https://example.com/new",
          group_id: group.id,
          creator_id: owner.id,
          actor: owner
        )
      )

    assert huddl.time_zone == time_zone
    assert DateTime.shift_zone!(huddl.starts_at, time_zone).hour == 9
    context
  end

  step "a physical huddl is at 9:00 AM in {string}",
       %{args: [time_zone]} = context do
    setup_physical_huddl(context, time_zone)
  end

  step "I move the huddl to a venue in {string}",
       %{args: [_time_zone]} = context do
    huddl =
      context.physical_huddl
      |> Ash.Changeset.for_update(:update, %{
        group_location_id: context.mountain_location.id
      })
      |> Ash.update!(actor: context.current_user)

    Map.put(context, :physical_huddl, huddl)
  end

  step "the moved huddl is at 9:00 AM in {string}",
       %{args: [time_zone]} = context do
    assert context.physical_huddl.time_zone == time_zone
    assert DateTime.shift_zone!(context.physical_huddl.starts_at, time_zone).hour == 9
    context
  end

  step "an attendee is going to a physical huddl at 9:00 AM in {string}",
       %{args: [time_zone]} = context do
    context = setup_physical_huddl(context, time_zone)

    attendee = generate(user(display_name: "Timezone Attendee"))
    Huddlz.Communities.rsvp_huddl!(context.physical_huddl, %{}, actor: attendee)
    Oban.drain_queue(queue: :notifications)
    drain_email_mailbox()

    Map.put(context, :timezone_attendee, attendee)
  end

  step "the organizer moves the huddl to a venue in {string}",
       %{args: [_time_zone]} = context do
    huddl =
      context.physical_huddl
      |> Ash.Changeset.for_update(:update, %{
        group_location_id: context.mountain_location.id
      })
      |> Ash.update!(actor: context.current_user)

    context = Map.put(context, :physical_huddl, huddl)

    Oban.drain_queue(queue: :notifications)

    email =
      drain_email_mailbox()
      |> Enum.find(fn email ->
        email.to == [{"", to_string(context.timezone_attendee.email)}] and
          email.subject == "Updated: Traveling Physical Huddl"
      end)

    assert email
    Map.put(context, :timezone_update_email, email)
  end

  step "the attendee should receive the updated time as {string}",
       %{args: [expected]} = context do
    assert context.timezone_update_email.text_body =~ expected
    context
  end

  step "adding the update to a Denver calendar should show 9:00 AM", context do
    assert [attachment] = context.timezone_update_email.attachments
    assert attachment.content_type == "text/calendar"
    assert [calendar_entry] = ICal.from_ics(attachment.data).events
    assert calendar_entry.uid == "huddl-#{context.physical_huddl.id}@huddlz.com"

    denver_start = DateTime.shift_zone!(calendar_entry.dtstart, "America/Denver")
    assert Calendar.strftime(denver_start, "%-I:%M %p") == "9:00 AM"
    context
  end

  step "I open its edit form from a browser in {string}",
       %{args: [time_zone]} = context do
    conn = browser_conn(context.current_user, time_zone)

    huddl = Ash.load!(context.physical_huddl, :group, authorize?: false)
    session = PhoenixTest.visit(conn, "/groups/#{huddl.group.slug}/huddlz/#{huddl.id}/edit")
    Map.merge(context, %{session: session, conn: session})
  end

  step "the edit form should show {string} in {string}",
       %{args: [wall_time, time_zone]} = context do
    assert_has(context.session, "#huddl-time-zone", text: time_zone)
    assert_has(context.session, "input[type='time'][value^='#{wall_time}']")
    context
  end

  step "a weekly virtual huddl starts at 9:00 AM before Eastern daylight saving time",
       context do
    owner = context.current_user

    group =
      create_saint_augustine_group(owner, "Recurring Neighbors", "America/New_York")

    huddl =
      generate(
        huddl(
          title: "Weekly Morning Huddl",
          date: ~D[2030-03-03],
          start_time: ~T[09:00:00],
          duration_minutes: 60,
          event_type: :virtual,
          virtual_link: "https://example.com/weekly",
          is_recurring: true,
          frequency: "weekly",
          repeat_until: ~D[2030-03-25],
          group_id: group.id,
          creator_id: owner.id,
          actor: owner
        )
      )

    Map.put(context, :recurring_huddl, huddl)
  end

  step "the recurring schedule crosses the daylight-saving transition", context do
    Oban.drain_queue(queue: :default)

    occurrences =
      Huddlz.Communities.Huddl
      |> Ash.Query.filter(huddl_template_id == ^context.recurring_huddl.huddl_template_id)
      |> Ash.Query.sort(starts_at: :asc)
      |> Ash.read!(authorize?: false)

    Map.put(context, :recurring_occurrences, occurrences)
  end

  step "every occurrence starts at 9:00 AM in {string}",
       %{args: [time_zone]} = context do
    assert length(context.recurring_occurrences) > 1

    assert Enum.all?(context.recurring_occurrences, fn huddl ->
             DateTime.shift_zone!(huddl.starts_at, time_zone).hour == 9
           end)

    context
  end

  step "attendees in UTC see the start time shift by one hour", context do
    utc_hours = Enum.map(context.recurring_occurrences, & &1.starts_at.hour) |> Enum.uniq()
    assert Enum.sort(utc_hours) == [13, 14]
    context
  end

  step "I change the whole recurring series to 10:00 AM", context do
    huddl = context.recurring_huddl

    updated =
      huddl
      |> Ash.Changeset.for_update(:update, %{
        date: huddl.starts_at |> DateTime.shift_zone!(huddl.time_zone) |> DateTime.to_date(),
        start_time: ~T[10:00:00],
        duration_minutes: 60,
        edit_type: "all",
        frequency: "weekly",
        repeat_until: ~D[2030-03-25]
      })
      |> Ash.update!(actor: context.current_user)

    occurrences =
      Huddlz.Communities.Huddl
      |> Ash.Query.filter(huddl_template_id == ^updated.huddl_template_id)
      |> Ash.Query.sort(starts_at: :asc)
      |> Ash.read!(authorize?: false)

    Map.put(context, :recurring_occurrences, occurrences)
  end

  step "every future occurrence starts at 10:00 AM in {string}",
       %{args: [time_zone]} = context do
    assert length(context.recurring_occurrences) > 1

    assert Enum.all?(context.recurring_occurrences, fn huddl ->
             DateTime.shift_zone!(huddl.starts_at, time_zone).hour == 10
           end)

    context
  end

  step "I enter November 3, 2030 at 1:30 AM", context do
    session = context[:session] || context[:conn]

    session =
      session
      |> choose("Virtual")
      |> fill_in("Date", with: "2030-11-03", exact: false)
      |> fill_in("Start time", with: "01:30", exact: false)

    Map.merge(context, %{session: session, conn: session})
  end

  step "I try to schedule a virtual huddl on March 10, 2030 at 2:30 AM", context do
    session = context[:session] || context[:conn]

    session =
      session
      |> visit("/groups/#{List.first(context.groups).slug}/huddlz/new")
      |> choose("Virtual")
      |> fill_in("Title", with: "Spring Forward Huddl", exact: false)
      |> fill_in("Date", with: "2030-03-10", exact: false)
      |> fill_in("Start time", with: "02:30", exact: false)
      |> fill_in("Online link", with: "https://example.com/spring", exact: false)
      |> click_button("Schedule huddl")

    Map.merge(context, %{session: session, conn: session})
  end

  step "the huddl {string} should not exist", %{args: [title]} = context do
    huddl =
      Huddlz.Communities.Huddl
      |> Ash.Query.filter(title == ^title)
      |> Ash.read_one!(authorize?: false)

    assert is_nil(huddl)
    context
  end

  step "I am attending a Denver huddl at 11:30 PM on July 15, 2030", context do
    attendee = context.current_user
    host = generate(user(role: :user))

    group =
      generate(
        group(
          name: "Denver Night Owls",
          location: "Denver, CO, USA",
          latitude: 39.7392,
          longitude: -104.9903,
          time_zone: "America/Denver",
          owner_id: host.id,
          actor: host
        )
      )

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
          title: "Denver Late Night Huddl",
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
    Map.merge(context, %{calendar_huddl: huddl, calendar_group: group})
  end

  step "I view Calendar from a browser in {string}",
       %{args: [time_zone]} = context do
    conn = browser_conn(context.current_user, time_zone)

    session = PhoenixTest.visit(conn, "/calendar?month=2030-07&view=month")
    Map.merge(context, %{session: session, conn: session})
  end

  step "Calendar should show {string} as the zone in use",
       %{args: [time_zone]} = context do
    assert_has(context.session, "#calendar-time-zone", text: time_zone)
    context
  end

  step "the Denver huddl should appear on July 16", context do
    assert_has(
      context.session,
      "td[aria-label^='Tuesday, July 16, 2030'] #calendar-entry-#{context.calendar_huddl.id}"
    )

    context
  end

  step "its calendar time should be {string}", %{args: [time]} = context do
    assert_has(
      context.session,
      "#calendar-entry-#{context.calendar_huddl.id} .cal-pill-time",
      text: time
    )

    context
  end

  step "I open the Denver huddl from a browser in {string}",
       %{args: [time_zone]} = context do
    conn = browser_conn(context.current_user, time_zone)

    huddl = context.calendar_huddl

    session =
      PhoenixTest.visit(conn, "/groups/#{context.calendar_group.slug}/huddlz/#{huddl.id}")

    Map.merge(context, %{session: session, conn: session})
  end

  step "its details should show {string}", %{args: [expected]} = context do
    assert_has(context.session, "#huddl-schedule-fact", text: expected)
    context
  end

  step "my confirmation should say {string}", %{args: [expected]} = context do
    Oban.drain_queue(queue: :notifications)

    email =
      context.current_user.email
      |> to_string()
      |> confirmation_email()

    assert email.text_body =~ expected
    context
  end

  step "I request that huddl through the JSON API", context do
    conn =
      Phoenix.ConnTest.build_conn()
      |> Plug.Conn.put_req_header("accept", "application/vnd.api+json")
      |> Phoenix.ConnTest.dispatch(
        HuddlzWeb.Endpoint,
        :get,
        "/api/json/huddlz/#{context.calendar_huddl.id}",
        nil
      )

    assert conn.status == 200
    Map.put(context, :api_huddl, Jason.decode!(conn.resp_body)["data"]["attributes"])
  end

  step "the API start should be {string}", %{args: [expected]} = context do
    assert context.api_huddl["starts_at"] == expected
    context
  end

  step "the API time zone should be {string}", %{args: [expected]} = context do
    assert context.api_huddl["time_zone"] == expected
    context
  end

  step "the current time falls on different dates in Saint Augustine and Denver", context do
    now = ~U[2030-09-01 05:30:00Z]
    Map.put(context, :search_now, now)
  end

  step "a Saint Augustine huddl starts at 9:00 AM on September 15, 2030", context do
    host = context.current_user

    group =
      create_saint_augustine_group(
        host,
        "Saint Augustine Search Group",
        "America/New_York"
      )

    venue =
      generate(
        group_location(
          name: "Saint Augustine Amphitheatre",
          address: "1340 A1A South, Saint Augustine, FL, USA",
          latitude: 29.8594,
          longitude: -81.2829,
          time_zone: "America/New_York",
          group_id: group.id,
          actor: host
        )
      )

    huddl =
      generate(
        huddl(
          title: "Saint Augustine September Huddl",
          date: ~D[2030-09-15],
          start_time: ~T[09:00:00],
          duration_minutes: 60,
          group_location_id: venue.id,
          group_id: group.id,
          creator_id: host.id,
          actor: host
        )
      )

    Map.put(context, :search_huddl, huddl)
  end

  step "I search this month within 25 miles of Saint Augustine", context do
    results =
      Huddlz.Communities.Huddl
      |> Ash.Query.new()
      |> Ash.Query.set_argument(:now, context.search_now)
      |> Ash.Query.for_read(:search, %{
        date_filter: :this_month,
        search_latitude: 29.9012,
        search_longitude: -81.3124,
        distance_miles: 25,
        search_time_zone: "America/New_York"
      })
      |> Ash.read!(authorize?: false)

    Map.put(context, :search_results, results)
  end

  step "the Saint Augustine huddl should be found", context do
    assert Enum.any?(context.search_results, &(&1.id == context.search_huddl.id))
    context
  end

  step "its search time should be {string}", %{args: [expected]} = context do
    local = DateTime.shift_zone!(context.search_huddl.starts_at, context.search_huddl.time_zone)
    assert Calendar.strftime(local, "%-I:%M %p %Z") == expected
    context
  end

  step "my saved home search is Saint Augustine in {string}",
       %{args: [time_zone]} = context do
    user =
      Huddlz.Accounts.update_home_location!(
        context.current_user,
        "Saint Augustine, FL, USA",
        29.9012,
        -81.3124,
        time_zone,
        actor: context.current_user
      )

    Map.put(context, :current_user, user)
  end

  step "I filter Discover to this month from a browser in {string}",
       %{args: [time_zone]} = context do
    conn = browser_conn(context.current_user, time_zone)

    session = conn |> PhoenixTest.visit("/discover") |> PhoenixTest.click_link("This month")
    Map.merge(context, %{session: session, conn: session})
  end

  step "I search this month near a location without a resolved time zone", context do
    result =
      Huddlz.Communities.Huddl
      |> Ash.Query.for_read(:search, %{
        date_filter: :this_month,
        search_latitude: 39.7392,
        search_longitude: -104.9903
      })
      |> Ash.read(authorize?: false)

    Map.put(context, :unresolved_search_result, result)
  end

  step "the search should require a resolved time zone", context do
    assert {:error, error} = context.unresolved_search_result
    assert Exception.message(error) =~ "search time zone must be resolved"
    context
  end

  step "the search should still use {string}", %{args: [time_zone]} = context do
    PhoenixTest.assert_path(context.session, "/discover", query: %{"time_zone" => time_zone})
    context
  end

  defp drain_email_mailbox(acc \\ []) do
    receive do
      {:email, email} -> drain_email_mailbox([email | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end

  defp confirmation_email(recipient) do
    drain_email_mailbox()
    |> Enum.find(fn email ->
      Enum.any?(email.to, fn {_name, address} -> address == recipient end) and
        String.starts_with?(email.subject, "You're going to")
    end)
    |> then(fn
      nil -> flunk("No RSVP confirmation email received for #{recipient}")
      email -> email
    end)
  end

  defp browser_conn(user, time_zone) do
    Phoenix.ConnTest.build_conn()
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Phoenix.LiveViewTest.put_connect_params(%{"timezone" => time_zone})
    |> login(user)
  end

  defp group_city_coordinates("Saint Augustine" <> _rest), do: {29.9012, -81.3124}
  defp group_city_coordinates("Austin" <> _rest), do: {30.2672, -97.7431}
  defp group_city_coordinates("San Francisco" <> _rest), do: {37.7749, -122.4194}

  defp create_saint_augustine_group(owner, name, time_zone) do
    generate(
      group(
        name: name,
        location: "Saint Augustine, FL, USA",
        latitude: 29.9012,
        longitude: -81.3124,
        time_zone: time_zone,
        owner_id: owner.id,
        actor: owner
      )
    )
  end

  defp setup_physical_huddl(context, time_zone) do
    owner = context.current_user

    group = create_saint_augustine_group(owner, "Traveling Physical Group", time_zone)

    eastern_location =
      generate(
        group_location(
          name: "Saint Augustine Library",
          address: "1960 N Ponce De Leon Blvd, Saint Augustine, FL, USA",
          latitude: 29.9186,
          longitude: -81.3237,
          time_zone: time_zone,
          group_id: group.id,
          actor: owner
        )
      )

    mountain_location =
      generate(
        group_location(
          name: "Denver Library",
          address: "10 W. Fourteenth Ave, Denver, CO, USA",
          latitude: 39.7392,
          longitude: -104.9903,
          time_zone: "America/Denver",
          group_id: group.id,
          actor: owner
        )
      )

    huddl =
      generate(
        huddl(
          title: "Traveling Physical Huddl",
          date: ~D[2030-07-15],
          start_time: ~T[09:00:00],
          duration_minutes: 60,
          group_location_id: eastern_location.id,
          group_id: group.id,
          creator_id: owner.id,
          actor: owner
        )
      )

    Map.merge(context, %{
      physical_huddl: huddl,
      mountain_location: mountain_location
    })
  end
end
