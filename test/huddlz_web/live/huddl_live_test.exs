defmodule HuddlzWeb.HuddlLiveTest do
  use HuddlzWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Huddlz.Generator

  describe "Huddl listing" do
    test "displays huddlz on the homepage", %{conn: conn} do
      # Create test data
      {_host, huddlz} = host_with_huddlz()

      {:ok, _view, html} = live(conn, "/")

      # Check that the page renders correctly
      assert html =~ "Find your huddl"
      assert html =~ "Search huddlz"

      # Check that huddlz are displayed
      huddl = List.first(huddlz)
      assert html =~ huddl.title
    end

    test "searches huddlz by title", %{conn: conn} do
      # Create test data with specific titles
      {host, _} = host_with_huddlz()

      _elixir_huddl =
        huddl(
          host: host,
          title: "Elixir Programming Workshop",
          description: "Learn functional programming"
        )
        |> generate()

      _python_huddl =
        huddl(
          host: host,
          title: "Python Data Science",
          description: "Data analysis with Python"
        )
        |> generate()

      {:ok, view, _html} = live(conn, "/")

      # Search for "Elixir"
      html = render_change(view, "search", %{"query" => "Elixir"})

      # Should find the Elixir huddl
      assert html =~ "Elixir Programming Workshop"
      # Should not find the Python huddl
      refute html =~ "Python Data Science"
    end

    test "searches huddlz by description", %{conn: conn} do
      # Create test data
      {host, _} = host_with_huddlz()

      _huddl_with_description =
        huddl(
          host: host,
          title: "Tech Talk",
          description: "Advanced Elixir patterns and best practices"
        )
        |> generate()

      _other_huddl =
        huddl(
          host: host,
          title: "Coffee Chat",
          description: "Casual morning meetup"
        )
        |> generate()

      {:ok, view, _html} = live(conn, "/")

      # Search for content in description
      html = render_change(view, "search", %{"query" => "Elixir patterns"})

      # Should find the huddl with matching description
      assert html =~ "Tech Talk"
      # Should not find the other huddl
      refute html =~ "Coffee Chat"
    end

    test "shows all huddlz when search is cleared", %{conn: conn} do
      # Create test data
      {host, _} = host_with_huddlz()

      huddl1 = huddl(host: host, title: "Elixir Workshop") |> generate()
      huddl2 = huddl(host: host, title: "JavaScript Basics") |> generate()

      {:ok, view, html} = live(conn, "/")

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

    test "shows 'No huddlz found' when search has no results", %{conn: conn} do
      # Create test data
      {host, _} = host_with_huddlz()

      huddl(host: host, title: "Elixir Workshop") |> generate()

      {:ok, view, _html} = live(conn, "/")

      # Search for something that doesn't exist
      html = render_change(view, "search", %{"query" => "nonexistent12345"})

      # Should show no results message
      assert html =~ "No huddlz found"
    end

    test "search button triggers search via form submit", %{conn: conn} do
      # Create test data
      {host, _} = host_with_huddlz()

      _elixir_huddl =
        huddl(
          host: host,
          title: "Elixir Programming Workshop"
        )
        |> generate()

      _python_huddl =
        huddl(
          host: host,
          title: "Python Data Science"
        )
        |> generate()

      {:ok, view, _html} = live(conn, "/")

      # Submit the form with search query
      html = render_submit(view, "search", %{"query" => "Elixir"})

      # Should find the Elixir huddl
      assert html =~ "Elixir Programming Workshop"
      # Should not find the Python huddl
      refute html =~ "Python Data Science"
    end

    test "search is case-insensitive", %{conn: conn} do
      # Create test data with explicit status and future date
      {host, _} = host_with_huddlz()

      future_date = DateTime.add(DateTime.utc_now(), 7, :day)

      _elixir_huddl =
        huddl(
          host: host,
          title: "Elixir Programming Workshop",
          status: "upcoming",
          starts_at: future_date,
          ends_at: DateTime.add(future_date, 2, :hour)
        )
        |> generate()

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

    test "partial search matches work", %{conn: conn} do
      # Create test data
      {host, _} = host_with_huddlz()

      _workshop_huddl =
        huddl(
          host: host,
          title: "Elixir Programming Workshop"
        )
        |> generate()

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
