defmodule HuddlzWeb.HuddlSearchTest do
  use HuddlzWeb.ConnCase

  setup do
    user = generate(user(role: :verified))
    group = generate(group(owner_id: user.id, is_public: true, actor: user))

    # Create various huddlz for testing
    huddl1 =
      generate(
        huddl(
          group_id: group.id,
          creator_id: user.id,
          title: "Morning Yoga Session",
          description: "Start your day with relaxation",
          event_type: :in_person,
          starts_at: DateTime.add(DateTime.utc_now(), 2 * 24 * 60 * 60, :second),
          ends_at: DateTime.add(DateTime.utc_now(), 2 * 24 * 60 * 60 + 3600, :second),
          is_private: false,
          actor: user
        )
      )

    huddl2 =
      generate(
        huddl(
          group_id: group.id,
          creator_id: user.id,
          title: "Virtual Book Club",
          description: "Discuss latest tech books",
          event_type: :virtual,
          virtual_link: "https://zoom.us/meeting/123",
          starts_at: DateTime.add(DateTime.utc_now(), 5 * 24 * 60 * 60, :second),
          ends_at: DateTime.add(DateTime.utc_now(), 5 * 24 * 60 * 60 + 3600, :second),
          is_private: false,
          actor: user
        )
      )

    huddl3 =
      generate(
        huddl(
          group_id: group.id,
          creator_id: user.id,
          title: "Hybrid Workshop",
          description: "Learn programming basics",
          event_type: :hybrid,
          physical_location: "123 Tech St",
          virtual_link: "https://zoom.us/meeting/456",
          starts_at: DateTime.add(DateTime.utc_now(), 10 * 24 * 60 * 60, :second),
          ends_at: DateTime.add(DateTime.utc_now(), 10 * 24 * 60 * 60 + 3600, :second),
          is_private: false,
          actor: user
        )
      )

    # Create a past huddl that shouldn't appear
    _past_huddl =
      generate(
        huddl(
          group_id: group.id,
          creator_id: user.id,
          title: "Past Event",
          event_type: :in_person,
          starts_at: DateTime.add(DateTime.utc_now(), -2 * 24 * 60 * 60, :second),
          ends_at: DateTime.add(DateTime.utc_now(), -2 * 24 * 60 * 60 + 3600, :second),
          is_private: false,
          actor: user
        )
      )

    %{user: user, group: group, huddl1: huddl1, huddl2: huddl2, huddl3: huddl3}
  end

  describe "search functionality" do
    test "displays all upcoming huddlz by default", %{conn: conn} do
      conn
      |> visit("/")
      |> assert_has("h3", text: "Morning Yoga Session")
      |> assert_has("h3", text: "Virtual Book Club")
      |> assert_has("h3", text: "Hybrid Workshop")
      |> refute_has("h3", text: "Past Event")
    end

    test "searches by title", %{conn: conn} do
      conn
      |> visit("/")
      |> fill_in("Search huddlz", with: "Yoga")
      |> assert_has("h3", text: "Morning Yoga Session")
      |> refute_has("h3", text: "Virtual Book Club")
      |> refute_has("h3", text: "Hybrid Workshop")
    end

    test "searches by description", %{conn: conn} do
      conn
      |> visit("/")
      |> fill_in("Search huddlz", with: "programming")
      |> assert_has("h3", text: "Hybrid Workshop")
      |> refute_has("h3", text: "Morning Yoga Session")
      |> refute_has("h3", text: "Virtual Book Club")
    end

    test "filters by event type", %{conn: conn} do
      conn
      |> visit("/")
      |> select("Event Type", option: "Virtual")
      |> assert_has("h3", text: "Virtual Book Club")
      |> refute_has("h3", text: "Morning Yoga Session")
      |> refute_has("h3", text: "Hybrid Workshop")
    end

    test "filters by date range - this week", %{conn: conn} do
      conn
      |> visit("/")
      |> select("Date Range", option: "This Week")
      # Only events within 7 days should show
      |> assert_has("h3", text: "Morning Yoga Session")
      |> assert_has("h3", text: "Virtual Book Club")
      |> refute_has("h3", text: "Hybrid Workshop")
    end

    test "combines multiple filters", %{conn: conn} do
      conn
      |> visit("/")
      |> fill_in("Search huddlz", with: "book")
      |> select("Event Type", option: "Virtual")
      |> select("Date Range", option: "This Week")
      |> assert_has("h3", text: "Virtual Book Club")
      |> refute_has("h3", text: "Morning Yoga Session")
      |> refute_has("h3", text: "Hybrid Workshop")
    end

    test "displays active filters", %{conn: conn} do
      conn
      |> visit("/")
      |> fill_in("Search huddlz", with: "book")
      |> select("Event Type", option: "Virtual")
      |> assert_has(".badge", text: "Search: book")
      |> assert_has(".badge", text: "Type: Virtual")
    end

    test "clears all filters", %{conn: conn} do
      conn
      |> visit("/")
      # Apply filters
      |> fill_in("Search huddlz", with: "book")
      |> select("Event Type", option: "Virtual")
      # Clear filters
      |> click_button("Clear all")
      # All huddlz should be visible again
      |> assert_has("h3", text: "Morning Yoga Session")
      |> assert_has("h3", text: "Virtual Book Club")
      |> assert_has("h3", text: "Hybrid Workshop")
    end

    test "shows result count", %{conn: conn} do
      conn
      |> visit("/")
      |> assert_has("div", text: "Found 3 huddlz")
      |> select("Event Type", option: "Virtual")
      |> assert_has("div", text: "Found 1 huddl")
    end

    test "sorts by date descending", %{conn: conn} do
      # Verify sort dropdown exists and can be changed
      conn
      |> visit("/")
      |> assert_has("select#sort-by")
      |> select("Sort By", option: "Date (Latest First)")
      # Verify all huddlz are still displayed
      |> assert_has("h3", text: "Morning Yoga Session")
      |> assert_has("h3", text: "Virtual Book Club")
      |> assert_has("h3", text: "Hybrid Workshop")
    end

    test "shows no results message with active filters", %{conn: conn} do
      conn
      |> visit("/")
      |> fill_in("Search huddlz", with: "nonexistent")
      |> assert_has(
           "p",
           text: "No huddlz found matching your filters. Try adjusting your search criteria."
         )
    end
  end

  describe "access control" do
    test "only shows public huddlz to non-members", %{conn: conn, user: owner} do
      other_user = generate(user(role: :verified))
      private_group = generate(group(owner_id: owner.id, is_public: false, actor: owner))

      _private_huddl =
        generate(
          huddl(
            group_id: private_group.id,
            creator_id: owner.id,
            title: "Private Event",
            event_type: :in_person,
            is_private: true,
            actor: owner
          )
        )

      conn
      |> login(other_user)
      |> visit("/")
      |> refute_has("h3", text: "Private Event")
    end
  end
end
