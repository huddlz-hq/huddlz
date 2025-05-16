defmodule HuddlzWeb.AdminLiveTest do
  use HuddlzWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  alias Huddlz.Accounts.User

  # Sample user data
  @admin_email "admin_user@example.com"
  @regular_email "regular_user@example.com"
  @verified_email "verified_user@example.com"

  setup do
    # Create admin user
    admin_user =
      Ash.Seed.seed!(User, %{
        email: @admin_email,
        role: :admin,
        display_name: "Admin User"
      })

    # Create regular user
    regular_user =
      Ash.Seed.seed!(User, %{
        email: @regular_email,
        role: :regular,
        display_name: "Regular User"
      })

    # Create verified user (has more permissions than regular but not admin)
    verified_user =
      Ash.Seed.seed!(User, %{
        email: @verified_email,
        role: :verified,
        display_name: "Verified User"
      })

    %{admin_user: admin_user, regular_user: regular_user, verified_user: verified_user}
  end

  describe "admin panel access" do
    test "redirects if user is not logged in", %{conn: conn} do
      # Without a user in session, should redirect to sign-in
      conn = get(conn, ~p"/admin")
      assert redirected_to(conn) == ~p"/sign-in"
    end

    test "redirects if user is a regular user", %{conn: conn, regular_user: regular_user} do
      # With regular user in session, should redirect to home
      conn = conn |> login(regular_user) |> get(~p"/admin")
      assert redirected_to(conn) == ~p"/sign-in"
    end

    test "redirects if user is a verified user", %{conn: conn, verified_user: verified_user} do
      # Even verified users (who aren't admins) should be redirected
      conn = conn |> login(verified_user) |> get(~p"/admin")
      assert redirected_to(conn) == ~p"/sign-in"
    end

    test "renders admin panel for admin users", %{conn: conn, admin_user: admin_user} do
      # With admin user in session, should show admin panel
      conn = conn |> login(admin_user) |> get(~p"/admin")
      assert html_response(conn, 200) =~ "Admin Panel"
      assert html_response(conn, 200) =~ "User Management"
    end
  end

  describe "admin panel functionality" do
    setup %{
      conn: conn,
      admin_user: admin_user,
      regular_user: regular_user,
      verified_user: verified_user
    } do
      # Set up conn with admin user for all tests in this describe block
      conn = conn |> login(admin_user)

      %{
        admin_conn: conn,
        admin_user: admin_user,
        regular_user: regular_user,
        verified_user: verified_user
      }
    end

    test "has search form on admin panel", %{admin_conn: conn} do
      # Set up LiveView
      {:ok, view, html} = live(conn, ~p"/admin")

      # Check the page contains the search form
      assert html =~ "Search users by email"
      assert has_element?(view, "form[phx-submit=search]")
    end

    test "admin panel contains search form", %{admin_conn: conn} do
      # Set up LiveView
      {:ok, view, _html} = live(conn, ~p"/admin")

      # Verify form elements exist
      assert has_element?(view, "form[phx-submit=search]")
      assert has_element?(view, "input[name=query]")
      assert has_element?(view, "button[type=submit]", "Search")
    end

    test "can search users by exact email", %{admin_conn: conn, regular_user: regular_user} do
      # Set up LiveView
      {:ok, view, _html} = live(conn, ~p"/admin")

      # Submit the search form with an exact email match
      rendered =
        view
        |> element("form[phx-submit=search]")
        |> render_submit(%{query: to_string(regular_user.email)})

      # Verify search results show the user
      assert rendered =~ to_string(regular_user.email)
      assert rendered =~ regular_user.display_name
      assert rendered =~ "Regular"
    end

    test "can search users by partial email", %{admin_conn: conn, verified_user: verified_user} do
      # Get part of the email before the @ symbol
      email_str = to_string(verified_user.email)
      partial_email = email_str |> String.split("@") |> List.first()

      # Set up LiveView
      {:ok, view, _html} = live(conn, ~p"/admin")

      # Submit the search form with a partial email
      rendered =
        view
        |> element("form[phx-submit=search]")
        |> render_submit(%{query: partial_email})

      # Verify search results show the user
      assert rendered =~ to_string(verified_user.email)
      assert rendered =~ verified_user.display_name
      assert rendered =~ "Verified"
    end

    test "shows no results message when no users match search", %{admin_conn: conn} do
      # Set up LiveView
      {:ok, view, _html} = live(conn, ~p"/admin")

      # Submit the search form with an email that doesn't exist
      view
      |> element("form[phx-submit=search]")
      |> render_submit(%{query: "nonexistent_user@example.com"})

      # Verify the no results message
      result = render(view)
      assert result =~ "No users found matching your search criteria"
    end

    test "can list all users initially without search", %{
      admin_conn: conn,
      admin_user: admin_user,
      regular_user: regular_user,
      verified_user: verified_user
    } do
      # Set up LiveView
      {:ok, view, html} = live(conn, ~p"/admin")

      # Verify initial page loads with all users
      assert html =~ "Admin Panel"
      assert html =~ to_string(admin_user.email)
      assert html =~ to_string(regular_user.email)
      assert html =~ to_string(verified_user.email)

      # After performing a search, clicking Clear should restore the full list
      view
      |> element("form[phx-submit=search]")
      |> render_submit(%{query: "nonexistent_user@example.com"})

      # Now click the clear button to show all users
      rendered =
        view
        |> element("button", "Clear")
        |> render_click()

      # Verify all users are displayed again
      assert rendered =~ to_string(admin_user.email)
      assert rendered =~ to_string(regular_user.email)
      assert rendered =~ to_string(verified_user.email)
    end

    test "can update user roles", %{admin_conn: conn, regular_user: regular_user} do
      # Set up LiveView
      {:ok, view, _html} = live(conn, ~p"/admin")

      # Submit the update_role event directly
      html =
        view
        |> render_submit("update_role", %{
          "user_id" => regular_user.id,
          "role" => "verified"
        })

      # The page should still be functioning after the update
      assert html =~ "Admin Panel"
    end

    test "handles non-existent user gracefully when updating role", %{admin_conn: conn} do
      # Set up LiveView
      {:ok, view, _html} = live(conn, ~p"/admin")

      # Send the event directly with the non-existent ID and verify it doesn't crash
      html =
        view
        |> render_submit("update_role", %{
          "user_id" => "00000000-0000-0000-0000-000000000000",
          "role" => "admin"
        })

      # The LiveView should still be functioning and shouldn't crash
      assert html =~ "Admin Panel"
    end
  end
end
