defmodule HuddlzWeb.HuddlLiveTest do
  use HuddlzWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
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

      {:ok, view, html} = live(conn, "/")

      # Check that the page renders correctly
      assert html =~ "Find your huddl"
      assert html =~ "Search huddlz"

      # The initial render won't have huddls because connected?(socket) is false
      # We need to use render/1 to get the connected view
      assert render(view) =~ public_huddl.title
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

      {:ok, view, _html} = live(conn, "/")

      # Search for "Elixir"
      html = render_change(view, "search", %{"query" => "Elixir"})

      # Should find the Elixir huddl
      assert html =~ "Elixir Programming Workshop"
      # Should not find the Python huddl
      refute html =~ "Python Data Science"
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

      {:ok, view, _html} = live(conn, "/")

      # Search for content in description
      html = render_change(view, "search", %{"query" => "Elixir patterns"})

      # Should find the huddl with matching description
      assert html =~ "Tech Talk"
      # Should not find the other huddl
      refute html =~ "Coffee Chat"
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

      {:ok, view, _html} = live(conn, "/")

      # Get the connected view
      html = render(view)

      # Initially should see both huddlz
      assert html =~ huddl1.title
      assert html =~ huddl2.title

      # Search for "Elixir"
      html = render_change(view, "search", %{"query" => "Elixir"})
      assert html =~ huddl1.title
      refute html =~ huddl2.title

      # Clear search
      html = render_change(view, "search", %{"query" => ""})

      # Should see both huddlz again
      assert html =~ huddl1.title
      assert html =~ huddl2.title
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

      {:ok, view, _html} = live(conn, "/")

      # Search for something that doesn't exist
      html = render_change(view, "search", %{"query" => "nonexistent12345"})

      # Should show no results message
      assert html =~ "No huddlz found"
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

      {:ok, view, _html} = live(conn, "/")

      # Submit the form with search query
      html = render_submit(view, "search", %{"query" => "Elixir"})

      # Should find the Elixir huddl
      assert html =~ "Elixir Programming Workshop"
      # Should not find the Python huddl
      refute html =~ "Python Data Science"
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

      {:ok, view, _html} = live(conn, "/")

      # Test each case variation
      html = render_change(view, "search", %{"query" => "elixir"})
      assert html =~ "Elixir Programming Workshop", "Lowercase search should work"

      html = render_change(view, "search", %{"query" => "ELIXIR"})
      assert html =~ "Elixir Programming Workshop", "Uppercase search should work"

      html = render_change(view, "search", %{"query" => "Elixir"})
      assert html =~ "Elixir Programming Workshop", "Title case search should work"

      html = render_change(view, "search", %{"query" => "eLiXiR"})
      assert html =~ "Elixir Programming Workshop", "Mixed case search should work"
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

      {:ok, view, _html} = live(conn, "/")

      # Test partial matches
      for query <- ["Eli", "Programming", "Work", "gram"] do
        html = render_change(view, "search", %{"query" => query})

        assert html =~ "Elixir Programming Workshop",
               "Partial search '#{query}' should find the huddl"
      end
    end
  end
end
