defmodule AgendaNearbySteps do
  use Cucumber.StepDefinition

  import Huddlz.Generator
  import PhoenixTest

  # St. Augustine, FL — the latitude and longitude every generated group
  # already carries, so a huddl seeded there is "near" this home location.
  @home %{text: "St. Augustine, FL", lat: 29.9012, lng: -81.3124, zone: "America/New_York"}
  # Reykjavik: thousands of miles outside any distance the agenda offers.
  @far %{lat: 64.1466, lng: -21.9426}
  # Gainesville is about 63 miles from St. Augustine and Tampa about 150, so
  # they sit either side of the agenda's 100-mile reach.
  @miles_away %{60 => %{lat: 29.6516, lng: -82.3248}, 150 => %{lat: 27.9506, lng: -82.4572}}

  step "my home search location is set", %{current_user: user} = context do
    Huddlz.Accounts.update_home_location!(
      user,
      @home.text,
      @home.lat,
      @home.lng,
      @home.zone,
      actor: user
    )

    context
  end

  step "I have no home search location", %{current_user: user} = context do
    Huddlz.Accounts.update_home_location!(user, nil, nil, nil, nil, actor: user)
    context
  end

  step "a group I have not joined has scheduled {string} near my home location",
       %{args: [title]} = context do
    seed_stranger_huddl(title, @home)
    context
  end

  step "a group I have not joined has scheduled {string} far from my home location",
       %{args: [title]} = context do
    seed_stranger_huddl(title, @far)
    context
  end

  step "a group I have not joined has scheduled {string} about {int} miles away",
       %{args: [title, miles]} = context do
    seed_stranger_huddl(title, Map.fetch!(@miles_away, miles))
    context
  end

  step "I am going to {string} near my home location",
       %{args: [title], current_user: attendee} = context do
    title
    |> seed_stranger_huddl(@home)
    |> Ash.Changeset.for_update(:rsvp, %{}, actor: attendee)
    |> Ash.update!()

    context
  end

  # Nearby is the one agenda scope that searches rather than reading the
  # person's own tables, so it lands asynchronously — wait for it the way
  # a person waits for the rows to appear.
  step "I switch to huddlz near me", %{session: session} = context do
    session = click_link(session, "#calendar-scope-nearby", "Nearby")
    Phoenix.LiveViewTest.render_async(session.view, 5_000)
    Map.merge(context, %{conn: session, session: session})
  end

  step "the agenda asks me where to look", %{session: session} = context do
    assert_has(session, "#calendar-nearby-no-location")
    context
  end

  step "the agenda offers to set my home location", %{session: session} = context do
    assert_has(session, "#calendar-nearby-no-location a", text: "Set your location")
    context
  end

  defp seed_stranger_huddl(title, place) do
    host = generate(user(role: :user))

    group =
      generate(
        group(
          name: "Strangers #{System.unique_integer([:positive])}",
          owner_id: host.id,
          is_public: true,
          actor: host
        )
      )

    seed_huddl(group, host, title, place)
  end

  # Seeded rather than created through the organizer action: the action
  # geocodes, and these huddlz need exact coordinates.
  defp seed_huddl(group, host, title, place) do
    starts_at = DateTime.add(DateTime.utc_now(), 3, :day)

    generate(
      huddl_at_location(
        group_id: group.id,
        creator_id: host.id,
        title: title,
        is_private: false,
        event_type: :in_person,
        latitude: place.lat,
        longitude: place.lng,
        starts_at: starts_at,
        ends_at: DateTime.add(starts_at, 2, :hour)
      )
    )
  end
end
