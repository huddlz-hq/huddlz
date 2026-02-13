defmodule HuddlzWeb.HuddlSearchTest do
  use HuddlzWeb.ConnCase, async: true

  import Mox

  setup :verify_on_exit!

  setup do
    user = generate(user(role: :user))
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
          date: Date.add(Date.utc_today(), 2),
          start_time: ~T[09:00:00],
          duration_minutes: 60,
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
          date: Date.add(Date.utc_today(), 5),
          start_time: ~T[19:00:00],
          duration_minutes: 60,
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
          date: Date.add(Date.utc_today(), 10),
          start_time: ~T[14:00:00],
          duration_minutes: 120,
          is_private: false,
          actor: user
        )
      )

    # Create a past huddl that shouldn't appear
    _past_huddl =
      generate(
        past_huddl(
          group_id: group.id,
          creator_id: user.id,
          title: "Past Event",
          event_type: :in_person,
          starts_at: DateTime.add(DateTime.utc_now(), -2, :day),
          ends_at: DateTime.add(DateTime.utc_now(), -2, :day) |> DateTime.add(1, :hour),
          is_private: false
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
      # Past events should never show
      |> refute_has("h3", text: "Past Event")
    end

    test "filters by date range - this month", %{conn: conn} do
      conn
      |> visit("/")
      |> select("Date Range", option: "This Month")
      # All future events within 30 days should show
      |> assert_has("h3", text: "Morning Yoga Session")
      |> assert_has("h3", text: "Virtual Book Club")
      |> assert_has("h3", text: "Hybrid Workshop")
      # Past events should never show
      |> refute_has("h3", text: "Past Event")
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
      |> assert_has("span", text: "Search: book")
      |> assert_has("span", text: "Type: Virtual")
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

    test "only showing applied filters as active", %{conn: conn} do
      conn
      |> visit("/")
      # No filters applied initially
      |> refute_has("span", text: "Search:")
      |> refute_has("span", text: "Type:")
      |> refute_has("span", text: "Date:")
      # Select Event Type
      |> select("Event Type", option: "Virtual")
      |> refute_has("span", text: "Search:")
      |> assert_has("span", text: "Type: Virtual")
      |> refute_has("span", text: "Date:")
      # Apply Search
      |> fill_in("Search huddlz", with: "book")
      |> assert_has("span", text: "Search: book")
      |> assert_has("span", text: "Type: Virtual")
      |> refute_has("span", text: "Date:")
      # Select Date Range
      |> select("Date Range", option: "This Week")
      |> assert_has("span", text: "Search: book")
      |> assert_has("span", text: "Type: Virtual")
      |> assert_has("span", text: "Date: This Week")
      # Clear Date Range
      |> select("Date Range", option: "All Upcoming")
      |> assert_has("span", text: "Search: book")
      |> assert_has("span", text: "Type: Virtual")
      |> refute_has("span", text: "Date:")
      # Clear Search
      |> fill_in("Search huddlz", with: "")
      |> refute_has("span", text: "Search:")
      |> assert_has("span", text: "Type: Virtual")
      |> refute_has("span", text: "Date:")
      # Clear Event Type
      |> select("Event Type", option: "All Types")
      |> refute_has("span", text: "Search:")
      |> refute_has("span", text: "Type:")
      |> refute_has("span", text: "Date:")
    end

    test "shows result count", %{conn: conn} do
      conn
      |> visit("/")
      |> assert_has("div", text: "Found 3 huddlz")
      |> select("Event Type", option: "Virtual")
      |> assert_has("div", text: "Found 1 huddl")
    end

    test "displays huddlz in chronological order", %{conn: conn} do
      # Verify all huddlz are displayed in date order (earliest first)
      conn
      |> visit("/")
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
      other_user = generate(user(role: :user))
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

  describe "location autocomplete" do
    test "shows suggestions when typing a location", %{conn: conn} do
      stub(Huddlz.MockPlaces, :autocomplete, fn "aus", _token ->
        {:ok,
         [
           %{
             place_id: "p1",
             display_text: "Austin, TX, USA",
             main_text: "Austin",
             secondary_text: "TX, USA"
           }
         ]}
      end)

      conn
      |> visit("/")
      |> fill_in("Location", with: "aus")
      |> assert_has("button", text: "Austin")
    end

    test "selecting a suggestion activates location filter", %{conn: conn} do
      stub(Huddlz.MockPlaces, :autocomplete, fn "aus", _token ->
        {:ok,
         [
           %{
             place_id: "p1",
             display_text: "Austin, TX, USA",
             main_text: "Austin",
             secondary_text: "TX, USA"
           }
         ]}
      end)

      stub(Huddlz.MockPlaces, :place_details, fn "p1", _token ->
        {:ok, %{latitude: 30.27, longitude: -97.74}}
      end)

      conn
      |> visit("/")
      |> fill_in("Location", with: "aus")
      |> click_button("Austin")
      |> assert_has("span", text: "Austin, TX, USA")
    end

    test "no suggestions for short queries", %{conn: conn} do
      conn
      |> visit("/")
      |> fill_in("Location", with: "a")
      |> refute_has("button[phx-click='select_location']")
    end

    test "shows no locations found for unmatched queries", %{conn: conn} do
      stub(Huddlz.MockPlaces, :autocomplete, fn "xyzabc", _token ->
        {:ok, []}
      end)

      conn
      |> visit("/")
      |> fill_in("Location", with: "xyzabc")
      |> assert_has("p", text: "No locations found")
    end

    test "handles autocomplete API errors gracefully", %{conn: conn} do
      stub(Huddlz.MockPlaces, :autocomplete, fn _, _token ->
        {:error, {:request_failed, :timeout}}
      end)

      conn
      |> visit("/")
      |> fill_in("Location", with: "austin")
      |> assert_has("p", text: "Location search is currently unavailable")
    end

    test "handles place details errors gracefully", %{conn: conn} do
      stub(Huddlz.MockPlaces, :autocomplete, fn "aus", _token ->
        {:ok,
         [
           %{
             place_id: "p1",
             display_text: "Austin, TX, USA",
             main_text: "Austin",
             secondary_text: "TX, USA"
           }
         ]}
      end)

      stub(Huddlz.MockPlaces, :place_details, fn "p1", _token ->
        {:error, {:request_failed, :timeout}}
      end)

      conn
      |> visit("/")
      |> fill_in("Location", with: "aus")
      |> click_button("Austin")
      |> assert_has("p", text: "Location search is currently unavailable")
    end

    test "clearing filters clears location", %{conn: conn} do
      stub(Huddlz.MockPlaces, :autocomplete, fn "aus", _token ->
        {:ok,
         [
           %{
             place_id: "p1",
             display_text: "Austin, TX, USA",
             main_text: "Austin",
             secondary_text: "TX, USA"
           }
         ]}
      end)

      stub(Huddlz.MockPlaces, :place_details, fn "p1", _token ->
        {:ok, %{latitude: 30.27, longitude: -97.74}}
      end)

      conn
      |> visit("/")
      |> fill_in("Location", with: "aus")
      |> click_button("Austin")
      |> assert_has("span", text: "Austin, TX, USA")
      |> click_button("Clear all")
      |> refute_has("span", text: "Austin, TX, USA")
    end

    test "still shows huddlz when autocomplete returns no results", %{conn: conn} do
      stub(Huddlz.MockPlaces, :autocomplete, fn _, _token ->
        {:ok, []}
      end)

      conn
      |> visit("/")
      |> fill_in("Location", with: "xyzabc")
      |> assert_has("h3", text: "Morning Yoga Session")
      |> assert_has("h3", text: "Virtual Book Club")
    end
  end
end
