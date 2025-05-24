defmodule HuddlzWeb.HuddlSearchTest do
  use HuddlzWeb.ConnCase
  import Phoenix.LiveViewTest

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
      {:ok, view, _html} = live(conn, "/")

      assert has_element?(view, "h3", "Morning Yoga Session")
      assert has_element?(view, "h3", "Virtual Book Club")
      assert has_element?(view, "h3", "Hybrid Workshop")
      refute has_element?(view, "h3", "Past Event")
    end

    test "searches by title", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view
      |> form("form", %{query: "Yoga"})
      |> render_change()

      assert has_element?(view, "h3", "Morning Yoga Session")
      refute has_element?(view, "h3", "Virtual Book Club")
      refute has_element?(view, "h3", "Hybrid Workshop")
    end

    test "searches by description", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view
      |> form("form", %{query: "programming"})
      |> render_change()

      assert has_element?(view, "h3", "Hybrid Workshop")
      refute has_element?(view, "h3", "Morning Yoga Session")
      refute has_element?(view, "h3", "Virtual Book Club")
    end

    test "filters by event type", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view
      |> form("form", %{event_type: "virtual"})
      |> render_change()

      assert has_element?(view, "h3", "Virtual Book Club")
      refute has_element?(view, "h3", "Morning Yoga Session")
      refute has_element?(view, "h3", "Hybrid Workshop")
    end

    test "filters by date range - this week", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view
      |> form("form", %{date_filter: "this_week"})
      |> render_change()

      # Only events within 7 days should show
      assert has_element?(view, "h3", "Morning Yoga Session")
      assert has_element?(view, "h3", "Virtual Book Club")
      refute has_element?(view, "h3", "Hybrid Workshop")
    end

    test "combines multiple filters", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view
      |> form("form", %{
        query: "book",
        event_type: "virtual",
        date_filter: "this_week"
      })
      |> render_change()

      assert has_element?(view, "h3", "Virtual Book Club")
      refute has_element?(view, "h3", "Morning Yoga Session")
      refute has_element?(view, "h3", "Hybrid Workshop")
    end

    test "displays active filters", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view
      |> form("form", %{query: "book", event_type: "virtual"})
      |> render_change()

      assert has_element?(view, ".badge", "Search: book")
      assert has_element?(view, ".badge", "Type: Virtual")
    end

    test "clears all filters", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Apply filters
      view
      |> form("form", %{query: "book", event_type: "virtual"})
      |> render_change()

      # Clear filters
      view
      |> element("button", "Clear all")
      |> render_click()

      # All huddlz should be visible again
      assert has_element?(view, "h3", "Morning Yoga Session")
      assert has_element?(view, "h3", "Virtual Book Club")
      assert has_element?(view, "h3", "Hybrid Workshop")
    end

    test "shows result count", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      assert has_element?(view, "div", "Found 3 huddlz")

      view
      |> form("form", %{event_type: "virtual"})
      |> render_change()

      assert has_element?(view, "div", "Found 1 huddl")
    end

    test "sorts by date descending", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view
      |> form("form", %{sort_by: "date_desc"})
      |> render_change()

      # Check that huddls are in reverse chronological order
      html = render(view)
      yoga_index = String.split(html, "Morning Yoga Session") |> List.first() |> String.length()
      book_index = String.split(html, "Virtual Book Club") |> List.first() |> String.length()
      workshop_index = String.split(html, "Hybrid Workshop") |> List.first() |> String.length()

      assert workshop_index < book_index
      assert book_index < yoga_index
    end

    test "shows no results message with active filters", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view
      |> form("form", %{query: "nonexistent"})
      |> render_change()

      assert has_element?(
               view,
               "p",
               "No huddlz found matching your filters. Try adjusting your search criteria."
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

      conn = login(conn, other_user)
      {:ok, view, _html} = live(conn, "/")

      refute has_element?(view, "h3", "Private Event")
    end
  end
end
