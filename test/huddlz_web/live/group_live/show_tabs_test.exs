defmodule HuddlzWeb.GroupLive.ShowTabsTest do
  use HuddlzWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  describe "Group show page tabs" do
    setup do
      # Create a user who can create groups and huddls
      user = generate(user(role: :user))

      # Create a public group
      group = generate(group(owner_id: user.id, is_public: true, actor: user))

      # Create upcoming huddls (future events)
      upcoming_huddls =
        Enum.map(1..12, fn i ->
          future_date = Date.add(Date.utc_today(), i)

          generate(
            huddl(
              group_id: group.id,
              creator_id: user.id,
              is_private: false,
              title: "Upcoming Event #{i}",
              date: future_date,
              start_time: ~T[14:00:00],
              duration_minutes: 60,
              actor: user
            )
          )
        end)

      # Create past huddls (past events)
      past_huddls =
        Enum.map(1..25, fn i ->
          generate(
            past_huddl(
              group_id: group.id,
              creator_id: user.id,
              is_private: false,
              title: "Past Event #{i}",
              starts_at: DateTime.add(DateTime.utc_now(), -i, :day),
              ends_at: DateTime.add(DateTime.utc_now(), -i, :day) |> DateTime.add(1, :hour)
            )
          )
        end)

      %{
        user: user,
        group: group,
        upcoming_huddls: upcoming_huddls,
        past_huddls: past_huddls
      }
    end

    test "displays upcoming events tab by default", %{
      conn: conn,
      group: group,
      upcoming_huddls: upcoming_huddls
    } do
      {:ok, view, _html} = live(conn, ~p"/groups/#{group.slug}")

      # Check that upcoming tab is active by default
      assert has_element?(view, "button.text-primary", "Upcoming")

      # Check that upcoming events are displayed (limited to 10)
      upcoming_titles = upcoming_huddls |> Enum.take(10) |> Enum.map(& &1.title)

      Enum.each(upcoming_titles, fn title ->
        assert has_element?(view, "h3", title)
      end)

      # Check that the 11th and 12th upcoming events are not displayed
      refute has_element?(view, "h3", "Upcoming Event 11")
      refute has_element?(view, "h3", "Upcoming Event 12")
    end

    test "switches to past events tab when clicked", %{conn: conn, group: group} do
      {:ok, view, _html} = live(conn, ~p"/groups/#{group.slug}")

      # Click on the Past tab
      view |> element("button", "Past") |> render_click()

      # Check that past tab is now active
      assert has_element?(view, "button.text-primary", "Past")

      # Check that past events are displayed
      assert has_element?(view, "h3", "Past Event 1")
      assert has_element?(view, "h3", "Past Event 2")
    end

    test "displays pagination for past events", %{conn: conn, group: group} do
      {:ok, view, _html} = live(conn, ~p"/groups/#{group.slug}")

      # Switch to past events tab
      view |> element("button", "Past") |> render_click()

      # Check that pagination controls are present
      assert has_element?(view, "button[phx-click=change_past_page]")

      # Check that only 10 events are displayed on first page
      assert has_element?(view, "h3", "Past Event 1")
      assert has_element?(view, "h3", "Past Event 10")
      refute has_element?(view, "h3", "Past Event 11")
    end

    test "navigates to next page of past events", %{conn: conn, group: group} do
      {:ok, view, _html} = live(conn, ~p"/groups/#{group.slug}")

      # Switch to past events tab
      view |> element("button", "Past") |> render_click()

      # Click next page (page 2 button)
      view |> element("button", "2") |> render_click()

      # Check that we're on page 2
      assert has_element?(view, "button.bg-primary", "2")

      # Check that events 11-20 are displayed
      assert has_element?(view, "h3", "Past Event 11")
      assert has_element?(view, "h3", "Past Event 20")
      refute has_element?(view, "h3", "Past Event 10")
      refute has_element?(view, "h3", "Past Event 21")
    end

    test "navigates to specific page of past events", %{conn: conn, group: group} do
      {:ok, view, _html} = live(conn, ~p"/groups/#{group.slug}")

      # Switch to past events tab
      view |> element("button", "Past") |> render_click()

      # Click on page 3
      view |> element("button", "3") |> render_click()

      # Check that we're on page 3
      assert has_element?(view, "button.bg-primary", "3")

      # Check that events 21-25 are displayed (last page)
      assert has_element?(view, "h3", "Past Event 21")
      assert has_element?(view, "h3", "Past Event 25")
      refute has_element?(view, "h3", "Past Event 20")
    end

    test "shows no past events message when group has no past events", %{conn: conn, user: user} do
      # Create a new group with no past events
      new_group = generate(group(owner_id: user.id, is_public: true, actor: user))

      {:ok, view, _html} = live(conn, ~p"/groups/#{new_group.slug}")

      # Switch to past events tab
      view |> element("button", "Past") |> render_click()

      # Check that no past events message is displayed
      assert has_element?(view, "p", "No past huddlz found.")
    end

    test "shows no upcoming events message when group has no upcoming events", %{
      conn: conn,
      user: user
    } do
      # Create a new group with no upcoming events
      new_group = generate(group(owner_id: user.id, is_public: true, actor: user))

      {:ok, view, _html} = live(conn, ~p"/groups/#{new_group.slug}")

      # Check that no upcoming events message is displayed
      assert has_element?(view, "p", "No upcoming huddlz scheduled.")
    end

    test "maintains tab state when switching between tabs", %{conn: conn, group: group} do
      {:ok, view, _html} = live(conn, ~p"/groups/#{group.slug}")

      # Start on upcoming tab
      assert has_element?(view, "button.text-primary", "Upcoming")

      # Switch to past events tab
      view |> element("button", "Past") |> render_click()
      assert has_element?(view, "button.text-primary", "Past")

      # Switch back to upcoming events tab
      view |> element("button", "Upcoming") |> render_click()
      assert has_element?(view, "button.text-primary", "Upcoming")
    end
  end

  describe "Group show page tabs with private groups" do
    setup do
      user = generate(user(role: :user))
      non_member = generate(user(role: :user))

      # Create a private group
      private_group = generate(group(owner_id: user.id, is_public: false, actor: user))

      %{
        user: user,
        non_member: non_member,
        private_group: private_group
      }
    end

    test "non-members cannot access private group", %{
      conn: conn,
      non_member: non_member,
      private_group: private_group
    } do
      conn = login(conn, non_member)

      {:error, {:redirect, %{to: "/groups"}}} = live(conn, ~p"/groups/#{private_group.slug}")
    end

    test "group members can access private group tabs", %{
      conn: conn,
      user: user,
      private_group: private_group
    } do
      conn = login(conn, user)

      {:ok, view, _html} = live(conn, ~p"/groups/#{private_group.slug}")

      # Check that tabs are present
      assert has_element?(view, "button", "Upcoming")
      assert has_element?(view, "button", "Past")
    end
  end
end
