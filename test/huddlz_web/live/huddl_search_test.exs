defmodule HuddlzWeb.HuddlSearchTest do
  use HuddlzWeb.ConnCase, async: true

  import Mox
  import Phoenix.LiveViewTest

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

    test "renders capacity label and progress bar for limited huddlz with no RSVPs", %{
      conn: conn,
      user: user,
      group: group
    } do
      generate(
        huddl(
          group_id: group.id,
          creator_id: user.id,
          title: "Capped Huddl",
          description: "Limited seats",
          event_type: :virtual,
          virtual_link: "https://zoom.us/j/cap",
          date: Date.add(Date.utc_today(), 3),
          start_time: ~T[12:00:00],
          duration_minutes: 60,
          is_private: false,
          max_attendees: 5,
          actor: user
        )
      )

      conn
      |> visit("/")
      |> assert_has("h3", text: "Capped Huddl")
      |> assert_has("span", text: "0/5 spots filled")
      |> assert_has("span", text: "Plenty of space")
      |> assert_has("div[style*='width: 0%']")
    end

    test "renders capacity label for limited huddlz with at least one RSVP", %{
      conn: conn,
      user: user,
      group: group
    } do
      capped =
        generate(
          huddl(
            group_id: group.id,
            creator_id: user.id,
            title: "Mostly Empty Capped Huddl",
            description: "Limited seats",
            event_type: :virtual,
            virtual_link: "https://zoom.us/j/cap2",
            date: Date.add(Date.utc_today(), 4),
            start_time: ~T[12:00:00],
            duration_minutes: 60,
            is_private: false,
            max_attendees: 5,
            actor: user
          )
        )

      capped
      |> Ash.Changeset.for_update(:rsvp, %{}, actor: user)
      |> Ash.update!()

      conn
      |> visit("/")
      |> assert_has("h3", text: "Mostly Empty Capped Huddl")
      |> assert_has("span", text: "1/5 spots filled")
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
      stub_places_autocomplete(%{"aus" => [:austin]})

      {:ok, view, _html} = live(conn, "/")

      view
      |> element("#location-autocomplete-input")
      |> render_change(%{"location-autocomplete_search" => "aus"})

      render_async(view)

      assert has_element?(view, "button", "Austin")
    end

    test "selecting a suggestion activates location filter", %{conn: conn} do
      stub_places_autocomplete(%{"aus" => [:austin]})
      stub_place_details(:defaults)

      {:ok, view, _html} = live(conn, "/")

      view
      |> element("#location-autocomplete-input")
      |> render_change(%{"location-autocomplete_search" => "aus"})

      render_async(view)

      view |> element("button", "Austin") |> render_click()
      render_async(view)

      html = render(view)
      assert html =~ "Austin, TX, USA"
    end

    test "no suggestions for short queries", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view
      |> element("#location-autocomplete-input")
      |> render_change(%{"location-autocomplete_search" => "a"})

      refute has_element?(view, "#location-autocomplete-listbox")
    end

    test "shows no locations found for unmatched queries", %{conn: conn} do
      stub_places_autocomplete(%{})

      {:ok, view, _html} = live(conn, "/")

      view
      |> element("#location-autocomplete-input")
      |> render_change(%{"location-autocomplete_search" => "xyzabc"})

      render_async(view)

      assert has_element?(view, "p", "No locations found")
    end

    test "handles autocomplete API errors gracefully", %{conn: conn} do
      stub_places_autocomplete_error({:request_failed, :timeout})

      {:ok, view, _html} = live(conn, "/")

      view
      |> element("#location-autocomplete-input")
      |> render_change(%{"location-autocomplete_search" => "austin"})

      render_async(view)

      assert has_element?(view, "p", "Location search is currently unavailable")
    end

    test "handles place details errors gracefully", %{conn: conn} do
      stub_places_autocomplete(%{"aus" => [:austin]})
      stub_place_details_error({:request_failed, :timeout})

      {:ok, view, _html} = live(conn, "/")

      view
      |> element("#location-autocomplete-input")
      |> render_change(%{"location-autocomplete_search" => "aus"})

      render_async(view)

      view |> element("button", "Austin") |> render_click()
      render_async(view)

      assert has_element?(view, "p", "Location search is currently unavailable")
    end

    test "clearing filters clears location", %{conn: conn} do
      stub_places_autocomplete(%{"aus" => [:austin]})
      stub_place_details(:defaults)

      {:ok, view, _html} = live(conn, "/")

      view
      |> element("#location-autocomplete-input")
      |> render_change(%{"location-autocomplete_search" => "aus"})

      render_async(view)

      view |> element("button", "Austin") |> render_click()
      render_async(view)

      html = render(view)
      assert html =~ "Austin, TX, USA"

      view |> element("button", "Clear all") |> render_click()

      html = render(view)
      refute html =~ "Austin, TX, USA"
    end

    test "still shows huddlz when autocomplete returns no results", %{conn: conn} do
      stub_places_autocomplete(%{})

      {:ok, view, _html} = live(conn, "/")

      view
      |> element("#location-autocomplete-input")
      |> render_change(%{"location-autocomplete_search" => "xyzabc"})

      render_async(view)

      html = render(view)
      assert html =~ "Morning Yoga Session"
      assert html =~ "Virtual Book Club"
    end

    test "clear location button removes location filter", %{conn: conn} do
      stub_places_autocomplete(%{"aus" => [:austin]})
      stub_place_details(:defaults)

      {:ok, view, _html} = live(conn, "/")

      view
      |> element("#location-autocomplete-input")
      |> render_change(%{"location-autocomplete_search" => "aus"})

      render_async(view)

      view |> element("button", "Austin") |> render_click()
      render_async(view)

      html = render(view)
      assert html =~ "Austin, TX, USA"

      view |> element("[aria-label='Clear location']") |> render_click()

      html = render(view)
      refute html =~ "Austin, TX, USA"
      assert html =~ "Morning Yoga Session"
    end

    test "clear location button doesn't affect other filters", %{conn: conn} do
      stub_places_autocomplete(%{"aus" => [:austin]})
      stub_place_details(:defaults)

      {:ok, view, _html} = live(conn, "/")

      # Apply text search filter
      view |> form("form", %{"query" => "Yoga"}) |> render_change()

      # Select location via component
      view
      |> element("#location-autocomplete-input")
      |> render_change(%{"location-autocomplete_search" => "aus"})

      render_async(view)

      view |> element("button", "Austin") |> render_click()
      render_async(view)

      html = render(view)
      assert html =~ "Austin, TX, USA"
      assert html =~ "Search: Yoga"

      # Clear just the location
      view |> element("[aria-label='Clear location']") |> render_click()

      html = render(view)
      refute html =~ "Austin, TX, USA"
      assert html =~ "Search: Yoga"
    end
  end

  describe "keyboard navigation" do
    setup %{conn: conn} do
      stub_places_autocomplete(%{
        "aus" => [
          :austin,
          %{
            place_id: "p2",
            display_text: "Austin, MN, USA",
            main_text: "Austin",
            secondary_text: "MN, USA"
          }
        ]
      })

      %{conn: conn}
    end

    test "ArrowDown highlights suggestions sequentially", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view
      |> element("#location-autocomplete-input")
      |> render_change(%{"location-autocomplete_search" => "aus"})

      render_async(view)

      view
      |> element("#location-autocomplete-input")
      |> render_keydown(%{"key" => "ArrowDown"})

      html = render(view)
      assert html =~ ~s(id="location-autocomplete-option-0")
      assert html =~ "bg-primary/20 border-l-primary"

      view
      |> element("#location-autocomplete-input")
      |> render_keydown(%{"key" => "ArrowDown"})

      html = render(view)
      assert html =~ ~s(id="location-autocomplete-option-1")
    end

    test "Escape closes suggestions", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view
      |> element("#location-autocomplete-input")
      |> render_change(%{"location-autocomplete_search" => "aus"})

      render_async(view)

      assert has_element?(view, "#location-autocomplete-listbox")

      view
      |> element("#location-autocomplete-input")
      |> render_keydown(%{"key" => "Escape"})

      refute has_element?(view, "#location-autocomplete-listbox")
    end

    test "Enter with highlighted suggestion selects it", %{conn: conn} do
      stub_place_details(:defaults)

      {:ok, view, _html} = live(conn, "/")

      view
      |> element("#location-autocomplete-input")
      |> render_change(%{"location-autocomplete_search" => "aus"})

      render_async(view)

      view
      |> element("#location-autocomplete-input")
      |> render_keydown(%{"key" => "ArrowDown"})

      view
      |> element("#location-autocomplete-input")
      |> render_keydown(%{"key" => "Enter"})

      render_async(view)

      html = render(view)
      assert html =~ "Austin, TX, USA"
    end
  end
end
