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
      |> visit("/")
      |> assert_has("input[placeholder='Find your huddl']")
      |> assert_has("button", text: "Search")
      |> assert_has("h3", text: public_huddl.title)
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
      |> visit("/")
      |> fill_in("Search huddlz", with: "Elixir")
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
      |> visit("/")
      |> fill_in("Search huddlz", with: "Elixir patterns")
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

      session =
        conn
        |> visit("/")

      # Initially should see both huddlz
      session
      |> assert_has("h3", text: huddl1.title)
      |> assert_has("h3", text: huddl2.title)

      # Search for "Elixir"
      session2 =
        session
        |> fill_in("Search huddlz", with: "Elixir")

      session2
      |> assert_has("h3", text: huddl1.title)
      |> refute_has("h3", text: huddl2.title)

      # Clear search
      session2
      |> fill_in("Search huddlz", with: "")
      # Should see both huddlz again
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
      |> visit("/")
      |> fill_in("Search huddlz", with: "nonexistent12345")
      # Should show no results message
      |> assert_has("p", text: "No huddlz found")
    end

    test "search button triggers search via form submit", %{
      conn: conn,
      host: host,
      public_group: public_group
    } do
      _elixir_huddl =
        generate(
          huddl(
            group_id: public_group.id,
            creator_id: host.id,
            is_private: false,
            title: "Elixir Programming Workshop",
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
            actor: host
          )
        )

      conn
      |> visit("/")
      |> fill_in("Search huddlz", with: "Elixir")
      |> click_button("Search")
      # Should find the Elixir huddl
      |> assert_has("h3", text: "Elixir Programming Workshop")
      # Should not find the Python huddl
      |> refute_has("h3", text: "Python Data Science")
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

      session = conn |> visit("/")

      # Test each case variation
      session
      |> fill_in("Search huddlz", with: "elixir")
      |> assert_has("h3", text: "Elixir Programming Workshop")

      session
      |> fill_in("Search huddlz", with: "ELIXIR")
      |> assert_has("h3", text: "Elixir Programming Workshop")

      session
      |> fill_in("Search huddlz", with: "Elixir")
      |> assert_has("h3", text: "Elixir Programming Workshop")

      session
      |> fill_in("Search huddlz", with: "eLiXiR")
      |> assert_has("h3", text: "Elixir Programming Workshop")
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

      session = conn |> visit("/")

      # Test partial matches
      for query <- ["Eli", "Programming", "Work", "gram"] do
        session
        |> fill_in("Search huddlz", with: query)
        |> assert_has("h3", text: "Elixir Programming Workshop")
      end
    end
  end

  describe "location search" do
    setup do
      host = generate(user(role: :user))
      public_group = generate(group(is_public: true, owner_id: host.id, actor: host))
      %{host: host, public_group: public_group}
    end

    test "clicking Search does not open location suggestions", %{
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

      # Select a location via the component
      session = conn |> visit("/")
      view = session.view

      view
      |> element("#location-autocomplete-input")
      |> render_change(%{"location-autocomplete_search" => "aus"})

      render_async(view)

      view |> element("[role='option']", "Austin") |> render_click()
      render_async(view)

      # The location should be active (in selected state)
      assert has_element?(view, "[data-testid='location-display']", "Austin, TX, USA")

      # Click Search button - should NOT reopen suggestions
      session |> click_button("Search")
      refute has_element?(view, "[role='option']")
    end
  end

  describe "Groups fallback" do
    setup do
      host = generate(user(role: :user))
      %{host: host}
    end

    test "shows groups when no huddlz exist", %{conn: conn, host: host} do
      generate(group(is_public: true, owner_id: host.id, actor: host, name: "Elixir Club"))

      conn
      |> visit("/")
      |> assert_has("h2", text: "Groups you can explore")
      |> assert_has("h2", text: "Elixir Club")
    end

    test "hides groups section when huddlz exist", %{conn: conn, host: host} do
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
      |> visit("/")
      |> assert_has("h3", text: "Active Huddl")
      |> refute_has("h2", text: "Groups you can explore")
    end

    test "group cards link to group detail page", %{conn: conn, host: host} do
      group =
        generate(
          group(is_public: true, owner_id: host.id, actor: host, name: "Linked Group Test")
        )

      {:ok, _view, html} = live(conn, ~p"/")

      assert html
             |> Floki.parse_document!()
             |> Floki.find("a")
             |> Enum.any?(fn link ->
               Floki.attribute(link, "href") == ["/groups/#{group.slug}"] &&
                 link |> Floki.text() |> String.contains?("Linked Group Test")
             end)
    end
  end

  describe "Personal sections" do
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

      %{
        host: host,
        attendee: attendee,
        stranger: stranger,
        host_group: host_group,
        stranger_group: stranger_group,
        hosted: hosted,
        foreign: foreign
      }
    end

    test "anonymous users see no personal sections", %{conn: conn} do
      conn
      |> visit("/")
      |> refute_has("span", text: "// Hosting")
      |> refute_has("span", text: "// Attending")
    end

    test "host sees Hosting section", %{conn: conn, host: host, hosted: hosted} do
      conn
      |> login(host)
      |> visit("/")
      |> assert_has("span", text: "// Hosting")
      |> assert_has("h3", text: hosted.title)
    end

    test "RSVPed attendee sees Attending section, not Hosting", %{
      conn: conn,
      attendee: attendee,
      foreign: foreign
    } do
      conn
      |> login(attendee)
      |> visit("/")
      |> assert_has("span", text: "// Attending")
      |> refute_has("span", text: "// Hosting")
      |> assert_has("h3", text: foreign.title)
    end

    test "host who also RSVPed to their own huddl is not double-counted", %{
      conn: conn,
      host: host,
      hosted: hosted
    } do
      hosted
      |> Ash.Changeset.for_update(:rsvp, %{}, actor: host)
      |> Ash.update!()

      conn
      |> login(host)
      |> visit("/")
      |> assert_has("span", text: "// Hosting")
      |> refute_has("span", text: "// Attending")
    end

    test "?yours=hosting scope shows only hosted, hides sections", %{
      conn: conn,
      host: host,
      hosted: hosted
    } do
      conn
      |> login(host)
      |> visit("/?yours=hosting")
      |> assert_has("h1", text: "Huddlz You're Hosting")
      |> assert_has("h3", text: hosted.title)
      |> refute_has("span", text: "// Hosting")
      |> assert_has("a", text: "All huddlz")
    end

    test "?yours=attending scope shows only attending", %{
      conn: conn,
      attendee: attendee,
      foreign: foreign
    } do
      conn
      |> login(attendee)
      |> visit("/?yours=attending")
      |> assert_has("h1", text: "Huddlz You're Attending")
      |> assert_has("h3", text: foreign.title)
    end

    test "anonymous users redirected from ?yours= scopes to sign-in", %{conn: conn} do
      session = conn |> visit("/?yours=hosting")
      assert_path(session, ~p"/sign-in")

      assert Phoenix.Flash.get(session.conn.assigns.flash, :error) =~
               "Sign in to view huddlz you're hosting"

      session = conn |> visit("/?yours=attending")
      assert_path(session, ~p"/sign-in")
    end

    test "View all link appears when hosting count exceeds limit", %{
      conn: conn,
      host: host
    } do
      group2 = generate(group(is_public: true, owner_id: host.id, actor: host))

      for i <- 1..7 do
        generate(
          huddl(
            group_id: group2.id,
            creator_id: host.id,
            is_private: false,
            title: "Heavy Hosting #{i}",
            actor: host
          )
        )
      end

      conn
      |> login(host)
      |> visit("/")
      |> assert_has(~s|a[href="/?yours=hosting"]|, text: "View all →")
    end

    test "scoped view with non-matching search shows search-aware empty copy", %{
      conn: conn,
      host: host
    } do
      conn
      |> login(host)
      |> visit("/?yours=hosting&q=zzznomatch")
      |> assert_has("p", text: "You aren't hosting any huddlz that match.")
    end
  end
end
