defmodule HuddlzWeb.HuddlSearchPaginationTest do
  use HuddlzWeb.ConnCase

  setup do
    user = generate(user(role: :user))
    group = generate(group(owner_id: user.id, is_public: true, actor: user))

    # Create 22 public upcoming huddlz to trigger pagination (20 per page)
    huddlz =
      for i <- 1..22 do
        event_type = Enum.random([:in_person, :virtual, :hybrid])

        base_attrs = %{
          group_id: group.id,
          creator_id: user.id,
          title: "Test Huddl #{i}",
          description: "Test event number #{i}",
          event_type: event_type,
          date: Date.add(Date.utc_today(), i),
          start_time: ~T[14:00:00],
          duration_minutes: 60,
          is_private: false,
          actor: user
        }

        # Add required fields based on event type
        attrs =
          case event_type do
            :in_person ->
              Map.put(base_attrs, :physical_location, "123 Test St")

            :virtual ->
              Map.put(base_attrs, :virtual_link, "https://zoom.us/meeting/#{i}")

            :hybrid ->
              base_attrs
              |> Map.put(:physical_location, "123 Test St")
              |> Map.put(:virtual_link, "https://zoom.us/meeting/#{i}")
          end

        generate(huddl(attrs))
      end

    # Create some past events that shouldn't appear
    for i <- 1..5 do
      generate(
        past_huddl(
          group_id: group.id,
          creator_id: user.id,
          title: "Past Event #{i}",
          event_type: :in_person,
          physical_location: "456 Past St",
          starts_at: DateTime.add(DateTime.utc_now(), -i, :day),
          ends_at: DateTime.add(DateTime.utc_now(), -i, :day) |> DateTime.add(1, :hour),
          is_private: false
        )
      )
    end

    # Create some private huddlz that shouldn't appear
    private_group = generate(group(owner_id: user.id, is_public: false, actor: user))

    for i <- 1..3 do
      generate(
        huddl(
          group_id: private_group.id,
          creator_id: user.id,
          title: "Private Event #{i}",
          event_type: :in_person,
          physical_location: "789 Private St",
          starts_at: DateTime.add(DateTime.utc_now(), i * 24 * 60 * 60, :second),
          ends_at: DateTime.add(DateTime.utc_now(), i * 24 * 60 * 60 + 3600, :second),
          is_private: false,
          actor: user
        )
      )
    end

    %{user: user, group: group, huddlz: huddlz}
  end

  describe "pagination controls" do
    test "shows pagination when more than 20 results", %{conn: conn} do
      conn
      |> visit("/")
      |> assert_has("button", text: "1")
      |> assert_has("button", text: "2")
      |> assert_has("button", text: "Next")
    end

    test "shows 20 results on first page", %{conn: conn} do
      conn
      |> visit("/")
      |> assert_has("div", text: "Found 20 huddlz")
      # Should see huddl 1-20
      |> assert_has("h3", text: "Test Huddl 1")
      |> assert_has("h3", text: "Test Huddl 20")
      # Should not see huddl 21-22
      |> refute_has("h3", text: "Test Huddl 21")
      |> refute_has("h3", text: "Test Huddl 22")
    end

    test "navigates to page 2", %{conn: conn} do
      conn
      |> visit("/")
      |> click_button("2")
      |> assert_has("div", text: "Found 2 huddlz")
      # Should see huddl 21-22
      |> assert_has("h3", text: "Test Huddl 21")
      |> assert_has("h3", text: "Test Huddl 22")
      # Should not see earlier huddlz
      |> refute_has("h3", text: "Test Huddl 1")
      |> refute_has("h3", text: "Test Huddl 20")
    end

    test "shows previous button on page 2", %{conn: conn} do
      conn
      |> visit("/")
      |> click_button("2")
      |> assert_has("button", text: "Previous")
    end

    test "navigates back to page 1", %{conn: conn} do
      conn
      |> visit("/")
      |> click_button("2")
      |> click_button("Previous")
      |> assert_has("div", text: "Found 20 huddlz")
      |> assert_has("h3", text: "Test Huddl 1")
    end

    test "doesn't show pagination with fewer than 20 results", %{conn: conn} do
      conn
      |> visit("/")
      # Filter to reduce results
      |> select("Event Type", option: "Virtual")
      # Should have fewer than 20 results
      |> refute_has("button", text: "Next")
      |> refute_has("button", text: "Previous")
    end

    test "pagination persists with filters", %{conn: conn} do
      # Create enough virtual events to paginate
      user = generate(user(role: :user))
      group = generate(group(owner_id: user.id, is_public: true, actor: user))

      for i <- 1..25 do
        generate(
          huddl(
            group_id: group.id,
            creator_id: user.id,
            title: "Virtual Event #{i}",
            description: "Virtual test event",
            event_type: :virtual,
            virtual_link: "https://zoom.us/meeting/virtual#{i}",
            starts_at: DateTime.add(DateTime.utc_now(), i * 24 * 60 * 60, :second),
            ends_at: DateTime.add(DateTime.utc_now(), i * 24 * 60 * 60 + 3600, :second),
            is_private: false,
            actor: user
          )
        )
      end

      conn
      |> visit("/")
      |> select("Event Type", option: "Virtual")
      # Should still have pagination
      |> assert_has("button", text: "2")
      |> click_button("2")
      # Filter should persist on page 2
      |> assert_has(".badge", text: "Type: Virtual")
    end

    test "pagination resets when applying new filter", %{conn: conn} do
      conn
      |> visit("/")
      |> click_button("2")
      # Apply a filter
      |> fill_in("Search huddlz", with: "Test")
      # Should be back on page 1
      |> assert_has("h3", text: "Test Huddl 1")
      |> refute_has("button", text: "Previous")
    end

    test "shows correct result count per page", %{conn: conn} do
      conn
      |> visit("/")
      |> assert_has("div", text: "Found 20 huddlz")
      |> click_button("Next")
      |> assert_has("div", text: "Found 2 huddlz")
    end
  end

  describe "edge cases" do
    test "handles empty search results", %{conn: conn} do
      conn
      |> visit("/")
      |> fill_in("Search huddlz", with: "nonexistent")
      |> assert_has("p", text: "No huddlz found matching your filters")
      # No pagination should be shown
      |> refute_has("button", text: "1")
      |> refute_has("button", text: "Next")
    end

    test "handles exactly 20 results", %{conn: conn} do
      # Clear existing data and create exactly 20 huddlz
      user = generate(user(role: :user))
      group = generate(group(owner_id: user.id, is_public: true, actor: user))

      # First, create a unique search term
      unique_term = "ExactlyTwenty#{System.unique_integer()}"

      for i <- 1..20 do
        generate(
          huddl(
            group_id: group.id,
            creator_id: user.id,
            title: "#{unique_term} Event #{i}",
            event_type: :in_person,
            physical_location: "100 Main St",
            starts_at: DateTime.add(DateTime.utc_now(), i * 24 * 60 * 60, :second),
            ends_at: DateTime.add(DateTime.utc_now(), i * 24 * 60 * 60 + 3600, :second),
            is_private: false,
            actor: user
          )
        )
      end

      conn
      |> visit("/")
      |> fill_in("Search huddlz", with: unique_term)
      |> assert_has("div", text: "Found 20 huddlz")
      # No pagination should be shown for exactly 20 results
      |> refute_has("button", text: "2")
      |> refute_has("button", text: "Next")
    end
  end
end
