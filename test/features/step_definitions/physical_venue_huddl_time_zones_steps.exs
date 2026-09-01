defmodule PhysicalVenueHuddlTimeZonesSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import Huddlz.Test.Helpers.Authentication
  import Huddlz.Test.Helpers.LocationSelection
  import PhoenixTest

  step "I am scheduling a {word} huddl", %{args: [type], conn: conn} = context do
    owner = generate(user(role: :user))
    group = generate(group(actor: owner, time_zone: "America/New_York"))

    session =
      conn
      |> login(owner)
      |> visit("/groups/#{group.slug}/huddlz/new")
      |> choose(if(type == "physical", do: "In person", else: "Hybrid"))
      |> fill_in("Title", with: "Denver Coffee")
      |> fill_in("Start time", with: "09:00")

    session =
      if type == "hybrid" do
        fill_in(session, "Online link", with: "https://meet.example.com/denver")
      else
        session
      end

    Map.merge(context, %{
      current_user: owner,
      group: group,
      huddl_type: type,
      session: session
    })
  end

  step "I select a venue in Denver", context do
    Mox.expect(Huddlz.MockLocationTimeZone, :resolve, fn 39.74, -104.99 ->
      {:ok, "America/Denver"}
    end)

    location =
      Huddlz.Communities.create_group_location!(
        "Denver Coffee",
        "1701 Wynkoop St, Denver, CO",
        39.74,
        -104.99,
        context.group.id,
        actor: context.current_user
      )

    session = select_saved_location(context.session, location)
    Map.merge(context, %{session: session, venue: location})
  end

  step "{string} is shown as the huddl time zone", %{args: [time_zone]} = context do
    context.session
    |> assert_has("#huddl-time-zone-derived[data-time-zone='#{time_zone}']")
    |> assert_has("#huddl-time-zone-derived", text: "Denver (#{time_zone})")

    context
  end

  step "I cannot replace it with an unrelated time zone", context do
    refute_has(context.session, "#huddl-time-zone[type='search']")
    context
  end

  step "the huddl is saved at the entered Denver wall-clock time", context do
    session = click_button(context.session, "Schedule huddl")

    [huddl | _] =
      Huddlz.Communities.get_group_huddlz!(context.group.id, actor: context.current_user)

    assert huddl.time_zone == "America/Denver"
    assert DateTime.shift_zone!(huddl.starts_at, "America/Denver").hour == 9
    assert DateTime.shift_zone!(huddl.ends_at, "America/Denver").hour == 10

    Map.put(context, :session, session)
  end

  step "I select a venue whose time zone cannot be resolved", %{conn: conn} = context do
    owner = generate(user(role: :user))
    group = generate(group(actor: owner, time_zone: "America/New_York"))

    session =
      conn
      |> login(owner)
      |> visit("/groups/#{group.slug}/huddlz/new")
      |> choose("In person")
      |> fill_in("Title", with: "Unknown Venue Coffee")
      |> fill_in("Start time", with: "09:00")

    unresolved_venue = %Huddlz.Communities.GroupLocation{
      name: "Unknown Venue",
      address: "Unknown Venue",
      latitude: 0.0,
      longitude: 0.0,
      time_zone: nil
    }

    session = select_saved_location(session, unresolved_venue)

    Map.merge(context, %{current_user: owner, group: group, session: session})
  end

  step "I try to save the huddl", context do
    Map.put(context, :session, click_button(context.session, "Schedule huddl"))
  end

  step "I am asked to choose a valid huddl time zone", context do
    context.session
    |> assert_has("#huddl-time-zone[type='search']")
    |> assert_has("#huddl-time-zone-error-0", text: "must be a valid IANA time zone")

    context
  end

  step "the huddl is not saved without one", context do
    assert [] ==
             Huddlz.Communities.get_group_huddlz!(context.group.id,
               actor: context.current_user
             )

    context
  end
end
