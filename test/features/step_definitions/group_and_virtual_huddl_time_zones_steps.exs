defmodule GroupAndVirtualHuddlTimeZonesSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import Huddlz.Test.Helpers.Authentication
  import Huddlz.Test.Helpers.LocationSelection
  import PhoenixTest

  step "my group's city uses {string}", %{args: [time_zone], conn: conn} = context do
    setup_group(context, conn, time_zone)
  end

  step "my group's time zone is {string}", %{args: [time_zone], conn: conn} = context do
    setup_group(context, conn, time_zone)
  end

  step "I schedule a virtual huddl for 9:00 AM", context do
    session =
      context.session
      |> choose("Virtual")
      |> fill_in("Title", with: "Virtual Coffee")
      |> fill_in("Start time", with: "09:00")
      |> fill_in("Online link", with: "https://meet.example.com/coffee")

    Map.put(context, :session, session)
  end

  step "{string} is shown as its huddl time zone", %{args: [time_zone]} = context do
    context.session
    |> assert_has(
      "#huddl-time-zone[type='search'][list='huddl-time-zone-options'][value='#{time_zone}']"
    )
    |> assert_has(
      "#huddl-time-zone-options option[value='#{time_zone}'][label='New York (#{time_zone})']"
    )

    context
  end

  step "the huddl is saved for 9:00 AM in that zone", context do
    session = click_button(context.session, "Schedule huddl")

    [huddl | _] =
      Huddlz.Communities.get_group_huddlz!(context.group.id, actor: context.current_user)

    assert huddl.time_zone == context.group.time_zone
    assert DateTime.shift_zone!(huddl.starts_at, huddl.time_zone).hour == 9

    Map.put(context, :session, session)
  end

  step "I schedule a virtual huddl in {string}", %{args: [time_zone]} = context do
    session =
      context.session
      |> choose("Virtual")
      |> fill_in("Title", with: "West Coast Virtual Coffee")
      |> fill_in("Start time", with: "09:00")
      |> fill_in("Online link", with: "https://meet.example.com/west")
      |> fill_in("huddl time zone", with: time_zone)
      |> click_button("Schedule huddl")

    Map.merge(context, %{session: session, selected_huddl_time_zone: time_zone})
  end

  step "its authoritative time is saved in {string}", %{args: [time_zone]} = context do
    [huddl | _] =
      Huddlz.Communities.get_group_huddlz!(context.group.id, actor: context.current_user)

    assert huddl.time_zone == time_zone
    assert DateTime.shift_zone!(huddl.starts_at, time_zone).hour == 9

    context
  end

  step "my group has a virtual huddl at 9:00 AM in {string}",
       %{args: [time_zone], conn: conn} = context do
    owner = generate(user(role: :user))
    group = generate(group(actor: owner, time_zone: time_zone))

    huddl =
      generate(
        huddl(
          actor: owner,
          creator_id: owner.id,
          group_id: group.id,
          title: "Existing Virtual Coffee",
          event_type: :virtual,
          physical_location: nil,
          virtual_link: "https://meet.example.com/existing",
          date: Date.add(Date.utc_today(), 7),
          start_time: ~T[09:00:00],
          duration_minutes: 60,
          time_zone: time_zone
        )
      )

    session = conn |> login(owner) |> visit("/groups/#{group.slug}/edit")

    Map.merge(context, %{
      current_user: owner,
      group: group,
      existing_huddl: huddl,
      session: session
    })
  end

  step "I change the group's city and Group time zone", context do
    Mox.expect(Huddlz.MockLocationTimeZone, :resolve, fn 39.74, -104.99 ->
      {:ok, "America/Denver"}
    end)

    Mox.allow(Huddlz.MockLocationTimeZone, self(), context.session.view.pid)

    session =
      context.session
      |> select_location(
        display_text: "Denver, CO, USA",
        latitude: 39.74,
        longitude: -104.99
      )
      |> click_button("#save-group-bottom", "Save Changes")

    group = Huddlz.Communities.get_by_slug!(context.group.slug, actor: context.current_user)

    Map.merge(context, %{session: session, group: group})
  end

  step "the existing huddl remains at 9:00 AM in {string}",
       %{args: [time_zone]} = context do
    huddl = Huddlz.Communities.get_huddl!(context.existing_huddl.id, actor: context.current_user)

    assert huddl.time_zone == time_zone
    assert DateTime.shift_zone!(huddl.starts_at, time_zone).hour == 9

    context
  end

  step "new virtual huddlz default to the new Group time zone", context do
    session =
      context.session
      |> visit("/groups/#{context.group.slug}/huddlz/new")
      |> choose("Virtual")

    assert_has(
      session,
      "#huddl-time-zone[value='#{context.group.time_zone}']"
    )

    assert context.group.time_zone == "America/Denver"

    Map.put(context, :session, session)
  end

  defp setup_group(context, conn, time_zone) do
    owner = generate(user(role: :user))
    group = generate(group(actor: owner, time_zone: time_zone))
    session = conn |> login(owner) |> visit("/groups/#{group.slug}/huddlz/new")

    Map.merge(context, %{current_user: owner, group: group, session: session})
  end
end
