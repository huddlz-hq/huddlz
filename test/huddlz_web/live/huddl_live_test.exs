defmodule HuddlzWeb.HuddlLiveTest do
  use HuddlzWeb.ConnCase, async: true

  import Huddlz.Generator
  import Mox
  import Phoenix.LiveViewTest

  setup :verify_on_exit!

  describe "Huddl listing" do
    setup do
      # Create a public group with a verified owner for all tests
      host = generate(user(role: :user))
      public_group = generate(group(is_public: true, owner_id: host.id, actor: host))

      %{host: host, public_group: public_group}
    end

    test "displays huddlz on the homepage", %{conn: conn, host: host, public_group: public_group} do
      public_huddl =
        generate(
          huddl(
            group_id: public_group.id,
            creator_id: host.id,
            is_private: false,
            title: "Public Huddl Test",
            actor: host
          )
        )

      conn
      |> visit("/discover")
      |> assert_has("input[placeholder='Search huddlz']")
      |> assert_has("h3", text: public_huddl.title)
    end

    test "renders huddl cards with v3 cover", %{
      conn: conn,
      host: host,
      public_group: public_group
    } do
      generate(
        huddl(
          group_id: public_group.id,
          creator_id: host.id,
          is_private: false,
          actor: host
        )
      )

      conn
      |> visit("/discover")
      |> assert_has(".grid .card .card-cover")
    end

    test "searches huddlz by title", %{conn: conn, host: host, public_group: public_group} do
      _elixir_huddl =
        generate(
          huddl(
            group_id: public_group.id,
            creator_id: host.id,
            is_private: false,
            title: "Elixir Programming Workshop",
            description: "Learn functional programming",
            actor: host
          )
        )

      _python_huddl =
        generate(
          huddl(
            group_id: public_group.id,
            creator_id: host.id,
            is_private: false,
            title: "Python Data Science",
            description: "Data analysis with Python",
            actor: host
          )
        )

      conn
      |> visit("/discover?q=Elixir")
      # Should find the Elixir huddl
      |> assert_has("h3", text: "Elixir Programming Workshop")
      # Should not find the Python huddl
      |> refute_has("h3", text: "Python Data Science")
    end

    test "searches huddlz by description", %{conn: conn, host: host, public_group: public_group} do
      _huddl_with_description =
        generate(
          huddl(
            group_id: public_group.id,
            creator_id: host.id,
            is_private: false,
            title: "Tech Talk",
            description: "Advanced Elixir patterns and best practices",
            actor: host
          )
        )

      _other_huddl =
        generate(
          huddl(
            group_id: public_group.id,
            creator_id: host.id,
            is_private: false,
            title: "Coffee Chat",
            description: "Casual morning meetup",
            actor: host
          )
        )

      conn
      |> visit("/discover?q=Elixir+patterns")
      # Should find the huddl with matching description
      |> assert_has("h3", text: "Tech Talk")
      # Should not find the other huddl
      |> refute_has("h3", text: "Coffee Chat")
    end

    test "shows all huddlz when search is cleared", %{
      conn: conn,
      host: host,
      public_group: public_group
    } do
      # Create test data
      huddl1 =
        generate(
          huddl(
            group_id: public_group.id,
            creator_id: host.id,
            is_private: false,
            title: "Elixir Workshop",
            actor: host
          )
        )

      huddl2 =
        generate(
          huddl(
            group_id: public_group.id,
            creator_id: host.id,
            is_private: false,
            title: "JavaScript Basics",
            actor: host
          )
        )

      # Initially both huddlz are visible.
      conn
      |> visit("/discover")
      |> assert_has("h3", text: huddl1.title)
      |> assert_has("h3", text: huddl2.title)

      # Searching for "Elixir" narrows to only the matching huddl.
      conn
      |> visit("/discover?q=Elixir")
      |> assert_has("h3", text: huddl1.title)
      |> refute_has("h3", text: huddl2.title)

      # Clearing the query brings everything back.
      conn
      |> visit("/discover")
      |> assert_has("h3", text: huddl1.title)
      |> assert_has("h3", text: huddl2.title)
    end

    test "shows 'No huddlz found' when search has no results", %{
      conn: conn,
      host: host,
      public_group: public_group
    } do
      generate(
        huddl(
          group_id: public_group.id,
          creator_id: host.id,
          is_private: false,
          title: "Elixir Workshop",
          actor: host
        )
      )

      conn
      |> visit("/discover?q=nonexistent12345")
      # Should show no results message
      |> assert_has("p", text: "No huddlz match this search")
    end

    test "search is case-insensitive", %{conn: conn, host: host, public_group: public_group} do
      _elixir_huddl =
        generate(
          huddl(
            group_id: public_group.id,
            creator_id: host.id,
            is_private: false,
            title: "Elixir Programming Workshop",
            date: Date.add(Date.utc_today(), 7),
            start_time: ~T[14:00:00],
            duration_minutes: 120,
            actor: host
          )
        )

      for query <- ["elixir", "ELIXIR", "Elixir", "eLiXiR"] do
        conn
        |> visit("/discover?q=" <> URI.encode_www_form(query))
        |> assert_has("h3", text: "Elixir Programming Workshop")
      end
    end

    test "partial search matches work", %{conn: conn, host: host, public_group: public_group} do
      _workshop_huddl =
        generate(
          huddl(
            group_id: public_group.id,
            creator_id: host.id,
            is_private: false,
            title: "Elixir Programming Workshop",
            actor: host
          )
        )

      for query <- ["Eli", "Programming", "Work", "gram"] do
        conn
        |> visit("/discover?q=" <> URI.encode_www_form(query))
        |> assert_has("h3", text: "Elixir Programming Workshop")
      end
    end

    test "empty discover with no filters shows the soft 'no upcoming' copy", %{conn: conn} do
      # No huddlz created in this test — the page should not nudge users
      # toward Groups when there are simply no upcoming huddlz to show.
      conn
      |> visit("/discover")
      |> assert_has("p", text: "No upcoming huddlz right now.")
      |> refute_has("p", text: "Try Groups")
    end
  end

  describe "location search" do
    setup do
      host = generate(user(role: :user))
      public_group = generate(group(is_public: true, owner_id: host.id, actor: host))
      %{host: host, public_group: public_group}
    end

    test "selecting a location closes the autocomplete dropdown", %{
      conn: conn,
      host: host,
      public_group: public_group
    } do
      stub_places_autocomplete(%{"aus" => [:austin]})
      stub_place_details(%{"p1" => %{latitude: 30.2672, longitude: -97.7431}})

      generate(
        huddl(
          group_id: public_group.id,
          creator_id: host.id,
          is_private: false,
          title: "Austin Meetup",
          physical_location: "123 Main St, Austin, TX",
          actor: host
        )
      )

      session = conn |> visit("/discover")
      view = session.view

      view
      |> element("#location-autocomplete-input")
      |> render_change(%{"location-autocomplete_search" => "aus"})

      render_async(view)

      view |> element("[role='option']", "Austin") |> render_click()
      render_async(view)

      # Location is active and the suggestions dropdown is closed.
      assert view |> element("[data-testid='location-display']") |> render() =~ "Austin, TX, USA"
      refute has_element?(view, "[role='option']")
    end

    test "discover URL with q + lat/lng renders search and location as active", %{conn: conn} do
      session =
        conn
        |> visit("/discover?q=elixir&location=Austin%2C+TX&lat=30.2672&lng=-97.7431&distance=25")

      session
      |> assert_has("h1", text: "Results for")
      |> assert_has("input[name='q'][value='elixir']")
      |> assert_has(".filter-distance input[type='range'][value='25']")
      |> assert_has(".filter-distance-value", text: "25 mi")
    end
  end

  describe "Groups scope (?scope=groups)" do
    setup do
      host = generate(user(role: :user))
      %{host: host}
    end

    test "lists public groups", %{conn: conn, host: host} do
      generate(group(is_public: true, owner_id: host.id, actor: host, name: "Elixir Club"))

      conn
      |> visit("/discover?scope=groups")
      |> assert_has("h1", text: "Browse groups")
      |> assert_has("h2", text: "Elixir Club")
    end

    test "hides huddlz when scope=groups", %{conn: conn, host: host} do
      public_group = generate(group(is_public: true, owner_id: host.id, actor: host))

      generate(
        huddl(
          group_id: public_group.id,
          creator_id: host.id,
          is_private: false,
          title: "Active Huddl",
          actor: host
        )
      )

      conn
      |> visit("/discover?scope=groups")
      |> refute_has("h3", text: "Active Huddl")
    end

    test "group cards link to group detail page", %{conn: conn, host: host} do
      group =
        generate(
          group(is_public: true, owner_id: host.id, actor: host, name: "Linked Group Test")
        )

      {:ok, _view, html} = live(conn, ~p"/discover?scope=groups")

      assert html
             |> Floki.parse_document!()
             |> Floki.find("a")
             |> Enum.any?(fn link ->
               Floki.attribute(link, "href") == ["/groups/#{group.slug}"] &&
                 link |> Floki.text() |> String.contains?("Linked Group Test")
             end)
    end

    test "default scope=huddlz does not show groups", %{conn: conn, host: host} do
      generate(group(is_public: true, owner_id: host.id, actor: host, name: "Hidden Club"))

      conn
      |> visit("/discover")
      |> refute_has("h2", text: "Hidden Club")
    end

    test "scope chips render with Huddlz active by default", %{conn: conn} do
      conn
      |> visit("/discover")
      |> assert_has(".scope-tab.is-active", text: "Huddlz")
      |> assert_has(".scope-tab", text: "Groups")
    end

    test "scope=groups empty state when no public groups", %{conn: conn} do
      conn
      |> visit("/discover?scope=groups&q=zzznomatch")
      |> assert_has("p", text: "No groups match this search")
    end
  end

  describe "Scoped views (?yours=...)" do
    setup do
      host = generate(user(role: :user))
      attendee = generate(user(role: :user))
      stranger = generate(user(role: :user))

      host_group = generate(group(is_public: true, owner_id: host.id, actor: host))
      stranger_group = generate(group(is_public: true, owner_id: stranger.id, actor: stranger))

      hosted =
        generate(
          huddl(
            group_id: host_group.id,
            creator_id: host.id,
            is_private: false,
            title: "Hosted by host",
            actor: host
          )
        )

      foreign =
        generate(
          huddl(
            group_id: stranger_group.id,
            creator_id: stranger.id,
            is_private: false,
            title: "Hosted by stranger",
            actor: stranger
          )
        )

      foreign
      |> Ash.Changeset.for_update(:rsvp, %{}, actor: attendee)
      |> Ash.update!()

      %{host: host, attendee: attendee, hosted: hosted, foreign: foreign}
    end

    test "?yours=hosting shows only hosted huddlz", %{conn: conn, host: host, hosted: hosted} do
      conn
      |> login(host)
      |> visit("/discover?yours=hosting")
      |> assert_has("h1", text: "huddlz you're hosting")
      |> assert_has("h3", text: hosted.title)
      |> assert_has("a", text: "All huddlz")
    end

    test "?yours=attending shows only attending", %{
      conn: conn,
      attendee: attendee,
      foreign: foreign
    } do
      conn
      |> login(attendee)
      |> visit("/discover?yours=attending")
      |> assert_has("h1", text: "huddlz you're attending")
      |> assert_has("h3", text: foreign.title)
    end

    test "← All huddlz back link preserves active filters", %{conn: conn, host: host} do
      conn
      |> login(host)
      |> visit("/discover?yours=hosting&q=elixir&date_filter=this_week")
      |> assert_has(~s|a[href="/discover?q=elixir&date_filter=this_week"]|,
        text: "All huddlz"
      )
    end

    test "anonymous users redirected from ?yours= scopes to sign-in", %{conn: conn} do
      session = conn |> visit("/discover?yours=hosting")
      assert_path(session, ~p"/sign-in")

      assert Phoenix.Flash.get(session.conn.assigns.flash, :error) =~
               "Sign in to view huddlz you're hosting"

      session = conn |> visit("/discover?yours=attending")
      assert_path(session, ~p"/sign-in")
    end

    test "scoped view with non-matching search shows search-aware empty copy", %{
      conn: conn,
      host: host
    } do
      conn
      |> login(host)
      |> visit("/discover?yours=hosting&q=zzznomatch")
      |> assert_has("p", text: "You aren't hosting any huddlz that match.")
    end
  end

  describe "Cleared location pre-fill" do
    test "anonymous visit to /discover does not produce ?cleared=1 in resulting URL", %{
      conn: conn
    } do
      session = conn |> visit("/discover")
      assert_path(session, ~p"/discover")
    end

    test "clearing location while pre-fill is active drops distance and lat/lng from URL", %{
      conn: conn
    } do
      user = generate(user(role: :user))

      user
      |> Ash.Changeset.for_update(
        :update_home_location,
        %{home_location: "Austin, TX", home_latitude: 30.2672, home_longitude: -97.7431},
        actor: user
      )
      |> Ash.update!()

      conn = login(conn, user)
      {:ok, view, _html} = Phoenix.LiveViewTest.live(conn, "/discover")

      view
      |> element(~s|button[aria-label="Clear location"]|)
      |> render_click()

      assert_patch(view, "/discover?cleared=1")
    end
  end
end
