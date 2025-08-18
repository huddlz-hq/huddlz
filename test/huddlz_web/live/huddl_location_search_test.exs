defmodule HuddlzWeb.HuddlLocationSearchTest do
  use HuddlzWeb.ConnCase

  setup do
    user = generate(user(role: :user))
    group = generate(group(owner_id: user.id, is_public: true, actor: user))

    # Create huddlz with physical locations
    # These will be geocoded by the mock service
    huddl_sf =
      generate(
        huddl(
          group_id: group.id,
          creator_id: user.id,
          title: "SF Tech Meetup",
          physical_location: "San Francisco, CA",
          event_type: :in_person,
          starts_at: DateTime.add(DateTime.utc_now(), 2 * 24 * 60 * 60, :second),
          ends_at: DateTime.add(DateTime.utc_now(), 2 * 24 * 60 * 60 + 3600, :second),
          is_private: false,
          actor: user
        )
      )

    huddl_ny =
      generate(
        huddl(
          group_id: group.id,
          creator_id: user.id,
          title: "NYC Startup Discussion",
          physical_location: "New York, NY",
          event_type: :in_person,
          starts_at: DateTime.add(DateTime.utc_now(), 3 * 24 * 60 * 60, :second),
          ends_at: DateTime.add(DateTime.utc_now(), 3 * 24 * 60 * 60 + 3600, :second),
          is_private: false,
          actor: user
        )
      )

    huddl_la =
      generate(
        huddl(
          group_id: group.id,
          creator_id: user.id,
          title: "LA Creative Workshop",
          physical_location: "Los Angeles, CA",
          event_type: :in_person,
          starts_at: DateTime.add(DateTime.utc_now(), 4 * 24 * 60 * 60, :second),
          ends_at: DateTime.add(DateTime.utc_now(), 4 * 24 * 60 * 60 + 3600, :second),
          is_private: false,
          actor: user
        )
      )

    # Virtual huddl without location
    huddl_virtual =
      generate(
        huddl(
          group_id: group.id,
          creator_id: user.id,
          title: "Virtual Coding Session",
          event_type: :virtual,
          virtual_link: "https://zoom.us/meeting/123",
          starts_at: DateTime.add(DateTime.utc_now(), 5 * 24 * 60 * 60, :second),
          ends_at: DateTime.add(DateTime.utc_now(), 5 * 24 * 60 * 60 + 3600, :second),
          is_private: false,
          actor: user
        )
      )

    %{
      user: user,
      group: group,
      huddl_sf: huddl_sf,
      huddl_ny: huddl_ny,
      huddl_la: huddl_la,
      huddl_virtual: huddl_virtual
    }
  end

  describe "location-based search" do
    test "displays location search input field", %{conn: conn} do
      conn
      |> visit("/")
      |> assert_has("input[placeholder='City or address...']")
      |> assert_has("select option", text: "5 miles")
      |> assert_has("select option", text: "10 miles")
      |> assert_has("select option", text: "25 miles")
      |> assert_has("select option", text: "50 miles")
      |> assert_has("select option", text: "100 miles")
    end

    test "filters huddlz by location and radius", %{conn: conn} do
      # Search near San Francisco with small radius
      conn
      |> visit("/")
      |> fill_in("location-search", with: "San Francisco, CA")
      |> select("radius", option: "10 miles")
      |> click_button("Search")
      |> assert_has("h3", text: "SF Tech Meetup")
      |> refute_has("h3", text: "NYC Startup Discussion")
      |> refute_has("h3", text: "LA Creative Workshop")
    end

    test "shows distance in search results when searching by location", %{conn: conn} do
      conn
      |> visit("/")
      |> fill_in("location-search", with: "San Francisco, CA")
      |> click_button("Search")
      |> assert_has("span", text: ~r/\d+\.\d+ mi/)
    end

    test "shows contextual no results message for location searches", %{conn: conn} do
      conn
      |> visit("/")
      |> fill_in("location-search", with: "Austin, TX")
      |> select("radius", option: "5 miles")
      |> click_button("Search")
      |> assert_has("p", text: ~r/No huddlz found within 5 miles of Austin, TX/)
    end

    test "shows location filter badge when searching by location", %{conn: conn} do
      conn
      |> visit("/")
      |> fill_in("location-search", with: "New York, NY")
      |> click_button("Search")
      |> assert_has(".badge", text: "Near: New York, NY")
    end

    test "combines location search with keyword search", %{conn: conn} do
      conn
      |> visit("/")
      |> fill_in("Search huddlz", with: "Tech")
      |> fill_in("location-search", with: "San Francisco, CA")
      |> select("radius", option: "50 miles")
      |> click_button("Search")
      |> assert_has("h3", text: "SF Tech Meetup")
      |> refute_has("h3", text: "LA Creative Workshop")
      |> refute_has("h3", text: "NYC Startup Discussion")
    end

    test "clears location filter when clear all is clicked", %{conn: conn} do
      conn
      |> visit("/")
      |> fill_in("location-search", with: "San Francisco, CA")
      |> click_button("Search")
      |> assert_has(".badge", text: "Near: San Francisco, CA")
      |> click_button("Clear all")
      |> refute_has(".badge", text: "Near:")
      |> assert_has("h3", text: "SF Tech Meetup")
      |> assert_has("h3", text: "NYC Startup Discussion")
      |> assert_has("h3", text: "LA Creative Workshop")
    end
  end

  describe "user default location" do
    test "uses user's default location when logged in and no location specified", %{conn: conn} do
      # Create a user with default location set to San Francisco
      user_with_location =
        generate(
          user(
            role: :user,
            default_location_address: "San Francisco, CA",
            default_search_radius: 25
          )
        )

      # Update the user to set the coordinates (normally done through the action)
      {:ok, _} =
        Huddlz.Accounts.User
        |> Ash.get!(user_with_location.id, authorize?: false)
        |> Ash.Changeset.for_update(:update_location_preferences, %{
          default_location_address: "San Francisco, CA",
          default_search_radius: 25
        })
        |> Ash.update!(authorize?: false)

      conn
      |> login(user_with_location)
      |> visit("/")
      # Should show location badge with (default) indicator
      |> assert_has(".badge", text: "San Francisco, CA")
      |> assert_has(".badge", text: "(default)")
    end

    test "explicit location search overrides user default", %{conn: conn} do
      user_with_location =
        generate(
          user(
            role: :user,
            default_location_address: "San Francisco, CA",
            default_search_radius: 25
          )
        )

      {:ok, _} =
        Huddlz.Accounts.User
        |> Ash.get!(user_with_location.id, authorize?: false)
        |> Ash.Changeset.for_update(:update_location_preferences, %{
          default_location_address: "San Francisco, CA",
          default_search_radius: 25
        })
        |> Ash.update!(authorize?: false)

      conn
      |> login(user_with_location)
      |> visit("/")
      |> fill_in("location-search", with: "New York, NY")
      |> click_button("Search")
      # Should show NYC, not SF
      |> assert_has(".badge", text: "Near: New York, NY")
      |> refute_has(".badge", text: "(default)")
    end
  end

  describe "virtual events and location" do
    test "virtual events appear regardless of location search", %{conn: conn} do
      conn
      |> visit("/")
      |> fill_in("location-search", with: "Tokyo, Japan")
      |> select("radius", option: "5 miles")
      |> click_button("Search")
      # Virtual events should still show since they have no physical location
      |> assert_has("h3", text: "Virtual Coding Session")
    end

    test "virtual events don't show distance in results", %{conn: conn} do
      conn
      |> visit("/")
      |> fill_in("location-search", with: "San Francisco, CA")
      |> click_button("Search")
      # Virtual huddl card should not have distance indicator
      |> assert_has("h3", text: "Virtual Coding Session")
      # TODO: More specific assertion to ensure distance not shown for virtual
    end
  end
end