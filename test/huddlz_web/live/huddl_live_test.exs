defmodule HuddlzWeb.HuddlLiveTest do
  use HuddlzWeb.ConnCase, async: true

  import Huddlz.Generator

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
      |> assert_has("h3", text: "Elixir Club")
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

      conn
      |> visit("/")
      |> assert_has("a[href='/groups/#{group.slug}']")
    end
  end
end
