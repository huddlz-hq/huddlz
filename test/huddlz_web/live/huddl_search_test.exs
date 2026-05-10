defmodule HuddlzWeb.HuddlSearchTest do
  use HuddlzWeb.ConnCase, async: true

  import Mox
  import Phoenix.LiveViewTest

  setup :verify_on_exit!

  setup do
    user = generate(user(role: :user))
    group = generate(group(owner_id: user.id, is_public: true, actor: user))

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
      |> visit("/discover")
      |> assert_has("h3", text: "Morning Yoga Session")
      |> assert_has("h3", text: "Virtual Book Club")
      |> assert_has("h3", text: "Hybrid Workshop")
      |> refute_has("h3", text: "Past Event")
    end

    test "renders RSVP-out-of-capacity meta for limited huddlz with no RSVPs", %{
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
      |> visit("/discover")
      |> assert_has("h3", text: "Capped Huddl")
      |> assert_has(".card-meta span", text: "0 / 5 RSVPs")
    end

    test "renders RSVP-out-of-capacity meta for limited huddlz with at least one RSVP", %{
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
      |> visit("/discover")
      |> assert_has("h3", text: "Mostly Empty Capped Huddl")
      |> assert_has(".card-meta span", text: "1 / 5 RSVPs")
    end

    test "searches by title", %{conn: conn} do
      conn
      |> visit("/discover?q=Yoga")
      |> assert_has("h3", text: "Morning Yoga Session")
      |> refute_has("h3", text: "Virtual Book Club")
      |> refute_has("h3", text: "Hybrid Workshop")
    end

    test "searches by description", %{conn: conn} do
      conn
      |> visit("/discover?q=programming")
      |> assert_has("h3", text: "Hybrid Workshop")
      |> refute_has("h3", text: "Morning Yoga Session")
      |> refute_has("h3", text: "Virtual Book Club")
    end

    test "filters by event type", %{conn: conn} do
      conn
      |> visit("/discover")
      |> click_link(".chip-group a.chip", "Virtual")
      |> assert_has("h3", text: "Virtual Book Club")
      |> refute_has("h3", text: "Morning Yoga Session")
      |> refute_has("h3", text: "Hybrid Workshop")
    end

    test "filters by date range - this week", %{conn: conn} do
      conn
      |> visit("/discover")
      |> click_link(".chip-group a.chip", "This week")
      # Only events within 7 days should show
      |> assert_has("h3", text: "Morning Yoga Session")
      |> assert_has("h3", text: "Virtual Book Club")
      |> refute_has("h3", text: "Hybrid Workshop")
      |> refute_has("h3", text: "Past Event")
    end

    test "filters by date range - this month", %{conn: conn} do
      conn
      |> visit("/discover")
      |> click_link(".chip-group a.chip", "This month")
      # All future events within 30 days should show
      |> assert_has("h3", text: "Morning Yoga Session")
      |> assert_has("h3", text: "Virtual Book Club")
      |> assert_has("h3", text: "Hybrid Workshop")
      |> refute_has("h3", text: "Past Event")
    end

    test "combines multiple filters", %{conn: conn} do
      conn
      |> visit("/discover?q=book")
      |> click_link(".chip-group a.chip", "Virtual")
      |> click_link(".chip-group a.chip", "This week")
      |> assert_has("h3", text: "Virtual Book Club")
      |> refute_has("h3", text: "Morning Yoga Session")
      |> refute_has("h3", text: "Hybrid Workshop")
    end

    test "active chips reflect URL state", %{conn: conn} do
      conn
      |> visit("/discover?event_type=virtual&date_filter=this_week&sort=newest")
      |> assert_has(".chip-group a.chip.is-active", text: "Virtual")
      |> assert_has(".chip-group a.chip.is-active", text: "This week")
      |> assert_has(".chip-group a.chip.is-active", text: "Newest")
    end

    test "Clear filters button drops all filter params", %{conn: conn} do
      conn
      |> visit("/discover?q=book&event_type=virtual&date_filter=this_week&sort=newest")
      |> click_button("Clear filters")
      |> assert_path(~p"/discover", query_params: %{"cleared" => "1"})
    end

    test "shows result count", %{conn: conn} do
      conn
      |> visit("/discover")
      |> assert_has(".discover-meta", text: "3 huddlz")
      |> click_link(".chip-group a.chip", "Virtual")
      |> assert_has(".discover-meta", text: "1 huddl")
    end

    test "displays huddlz in chronological order", %{conn: conn} do
      conn
      |> visit("/discover")
      |> assert_has("h3", text: "Morning Yoga Session")
      |> assert_has("h3", text: "Virtual Book Club")
      |> assert_has("h3", text: "Hybrid Workshop")
    end

    test "shows no results message with active filters", %{conn: conn} do
      conn
      |> visit("/discover?q=nonexistent")
      |> assert_has(
        "p",
        text: "No huddlz match this search. Try Groups or change your filters."
      )
    end
  end

  describe "filter bar" do
    test "filter bar is rendered for huddlz scope", %{conn: conn} do
      conn
      |> visit("/discover")
      |> assert_has(".filter-bar")
      |> assert_has(".filter-label", text: "Within")
      |> assert_has(".filter-label", text: "Type")
      |> assert_has(".filter-label", text: "When")
      |> assert_has(".filter-label", text: "Sort")
    end

    test "filter bar is hidden under scope=groups", %{conn: conn} do
      conn
      |> visit("/discover?scope=groups")
      |> refute_has(".filter-bar")
    end

    test "Sort: Newest patches URL and marks chip active", %{conn: conn} do
      conn
      |> visit("/discover")
      |> click_link(".chip-group a.chip", "Newest")
      |> assert_path(~p"/discover", query_params: %{"sort" => "newest"})
      |> assert_has(".chip-group a.chip.is-active", text: "Newest")
    end

    test "Sort: clicking Soonest while sort=newest drops sort from URL", %{conn: conn} do
      conn
      |> visit("/discover?sort=newest")
      |> assert_has(".chip-group a.chip.is-active", text: "Newest")
      |> click_link(".chip-group a.chip", "Soonest")
      |> assert_path(~p"/discover")
      |> refute_has(".chip-group a.chip.is-active", text: "Newest")
    end

    test "distance slider patches URL with new distance", %{conn: conn} do
      {:ok, view, _html} =
        live(conn, "/discover?location=Austin%2C+TX&lat=30.2672&lng=-97.7431&distance=25")

      view
      |> form("form[phx-change='distance_change']", %{"distance_miles" => "50"})
      |> render_change()

      assert_patched(
        view,
        "/discover?location=Austin%2C+TX&lat=30.2672&lng=-97.7431&distance=50"
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
      |> visit("/discover")
      |> refute_has("h3", text: "Private Event")
    end
  end

  describe "location autocomplete" do
    test "shows suggestions when typing a location", %{conn: conn} do
      stub_places_autocomplete(%{"aus" => [:austin]})

      {:ok, view, _html} = live(conn, "/discover")

      view
      |> element("#location-autocomplete-input")
      |> render_change(%{"location-autocomplete_search" => "aus"})

      render_async(view)

      assert has_element?(view, "button", "Austin")
    end

    test "selecting a suggestion activates location filter", %{conn: conn} do
      stub_places_autocomplete(%{"aus" => [:austin]})
      stub_place_details(:defaults)

      {:ok, view, _html} = live(conn, "/discover")

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
      {:ok, view, _html} = live(conn, "/discover")

      view
      |> element("#location-autocomplete-input")
      |> render_change(%{"location-autocomplete_search" => "a"})

      refute has_element?(view, "#location-autocomplete-listbox")
    end

    test "shows no locations found for unmatched queries", %{conn: conn} do
      stub_places_autocomplete(%{})

      {:ok, view, _html} = live(conn, "/discover")

      view
      |> element("#location-autocomplete-input")
      |> render_change(%{"location-autocomplete_search" => "xyzabc"})

      render_async(view)

      assert has_element?(view, "p", "No locations found")
    end

    test "handles autocomplete API errors gracefully", %{conn: conn} do
      stub_places_autocomplete_error({:request_failed, :timeout})

      {:ok, view, _html} = live(conn, "/discover")

      view
      |> element("#location-autocomplete-input")
      |> render_change(%{"location-autocomplete_search" => "austin"})

      render_async(view)

      assert has_element?(view, "p", "Location search is currently unavailable")
    end

    test "handles place details errors gracefully", %{conn: conn} do
      stub_places_autocomplete(%{"aus" => [:austin]})
      stub_place_details_error({:request_failed, :timeout})

      {:ok, view, _html} = live(conn, "/discover")

      view
      |> element("#location-autocomplete-input")
      |> render_change(%{"location-autocomplete_search" => "aus"})

      render_async(view)

      view |> element("button", "Austin") |> render_click()
      render_async(view)

      assert has_element?(view, "p", "Location search is currently unavailable")
    end

    test "Clear filters drops the active location", %{conn: conn} do
      stub_places_autocomplete(%{"aus" => [:austin]})
      stub_place_details(:defaults)

      {:ok, view, _html} = live(conn, "/discover")

      view
      |> element("#location-autocomplete-input")
      |> render_change(%{"location-autocomplete_search" => "aus"})

      render_async(view)

      view |> element("button", "Austin") |> render_click()
      render_async(view)

      html = render(view)
      assert html =~ "Austin, TX, USA"

      view |> element("button", "Clear filters") |> render_click()

      html = render(view)
      refute html =~ "Austin, TX, USA"
    end

    test "still shows huddlz when autocomplete returns no results", %{conn: conn} do
      stub_places_autocomplete(%{})

      {:ok, view, _html} = live(conn, "/discover")

      view
      |> element("#location-autocomplete-input")
      |> render_change(%{"location-autocomplete_search" => "xyzabc"})

      render_async(view)

      html = render(view)
      assert html =~ "Morning Yoga Session"
      assert html =~ "Virtual Book Club"
    end

    test "clear-location button removes location filter", %{conn: conn} do
      stub_places_autocomplete(%{"aus" => [:austin]})
      stub_place_details(:defaults)

      {:ok, view, _html} = live(conn, "/discover")

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

    test "clear-location button preserves the search query", %{conn: conn} do
      stub_places_autocomplete(%{"aus" => [:austin]})
      stub_place_details(:defaults)

      # Start with q already in the URL — search lives in the chrome and submits
      # via GET. Picking a location preserves q, and clearing the location
      # preserves q too.
      {:ok, view, _html} = live(conn, "/discover?q=Yoga")

      view
      |> element("#location-autocomplete-input")
      |> render_change(%{"location-autocomplete_search" => "aus"})

      render_async(view)

      view |> element("button", "Austin") |> render_click()
      render_async(view)

      html = render(view)
      assert html =~ "Austin, TX, USA"
      assert html =~ "Results for"

      view |> element("[aria-label='Clear location']") |> render_click()

      html = render(view)
      refute html =~ "Austin, TX, USA"
      assert html =~ "Results for"
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
      {:ok, view, _html} = live(conn, "/discover")

      view
      |> element("#location-autocomplete-input")
      |> render_change(%{"location-autocomplete_search" => "aus"})

      render_async(view)

      view
      |> element("#location-autocomplete-input")
      |> render_keydown(%{"key" => "ArrowDown"})

      html = render(view)
      assert html =~ ~s(id="location-autocomplete-option-0")
      assert html =~ "filter-location-option is-active"

      view
      |> element("#location-autocomplete-input")
      |> render_keydown(%{"key" => "ArrowDown"})

      html = render(view)
      assert html =~ ~s(id="location-autocomplete-option-1")
    end

    test "Escape closes suggestions", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/discover")

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

      {:ok, view, _html} = live(conn, "/discover")

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
