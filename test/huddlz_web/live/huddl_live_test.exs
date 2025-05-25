defmodule HuddlzWeb.HuddlLiveTest do
  use HuddlzWeb.ConnCase, async: true

  import Huddlz.Generator

  describe "Huddl listing" do
    setup do
      # Create a public group with a verified owner for all tests
      host = generate(user(role: :verified))
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
      |> assert_has("h1", text: "Find your huddl")
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
      future_date = DateTime.add(DateTime.utc_now(), 7, :day)

      _elixir_huddl =
        generate(
          huddl(
            group_id: public_group.id,
            creator_id: host.id,
            is_private: false,
            title: "Elixir Programming Workshop",
            starts_at: future_date,
            ends_at: DateTime.add(future_date, 2, :hour),
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
end
