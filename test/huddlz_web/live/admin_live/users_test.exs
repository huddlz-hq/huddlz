defmodule HuddlzWeb.AdminLive.UsersTest do
  use HuddlzWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Huddlz.Accounts.User

  @admin_email "admin_user@example.com"
  @regular_email "regular_user@example.com"
  @verified_email "verified_user@example.com"

  setup do
    admin_user =
      Ash.Seed.seed!(User, %{
        email: @admin_email,
        role: :admin,
        display_name: "Admin User",
        confirmed_at: DateTime.utc_now()
      })

    regular_user =
      Ash.Seed.seed!(User, %{
        email: @regular_email,
        role: :user,
        display_name: "Regular User",
        confirmed_at: DateTime.utc_now()
      })

    verified_user =
      Ash.Seed.seed!(User, %{
        email: @verified_email,
        role: :user,
        display_name: "Verified User",
        confirmed_at: DateTime.utc_now()
      })

    %{admin_user: admin_user, regular_user: regular_user, verified_user: verified_user}
  end

  describe "admin panel access" do
    test "redirects if user is not logged in", %{conn: conn} do
      conn
      |> visit(~p"/admin/users")
      |> assert_path(~p"/sign-in")
    end

    test "redirects if user is a non-admin user", %{conn: conn, regular_user: regular_user} do
      conn = login(conn, regular_user)

      assert {:error,
              {:redirect,
               %{
                 to: "/agenda",
                 flash: %{"error" => "You don't have access to the admin area."}
               }}} = live(conn, ~p"/admin/users")

      # The denied request must not clear the authenticated session.
      assert {:ok, _view, _html} = live(conn, ~p"/profile")
    end

    test "redirects all non-admin users", %{conn: conn, verified_user: verified_user} do
      conn
      |> login(verified_user)
      |> visit(~p"/admin/users")
      |> assert_path(~p"/agenda")
      |> assert_has("div[role='alert']", text: "You don't have access to the admin area.")
    end

    test "renders the roster for admin users", %{conn: conn, admin_user: admin_user} do
      conn
      |> login(admin_user)
      |> visit(~p"/admin/users")
      |> assert_has("h1", text: "Users")
      |> assert_has("section[aria-labelledby='role-admins-heading']", text: "Admin User")
      |> assert_has("section[aria-labelledby='role-people-heading']", text: "Regular User")
    end
  end

  describe "admin panel functionality" do
    setup %{conn: conn, admin_user: admin_user} do
      %{admin_conn: login(conn, admin_user)}
    end

    test "has a search form", %{admin_conn: conn} do
      conn
      |> visit(~p"/admin/users")
      |> assert_has("form[phx-submit=search]")
      |> assert_has("input[name=query]")
      |> assert_has("button[type=submit]", text: "Search")
    end

    test "lists every account with its email", %{
      admin_conn: conn,
      regular_user: regular_user,
      verified_user: verified_user
    } do
      conn
      |> visit(~p"/admin/users")
      |> assert_has(".member-row", text: to_string(regular_user.email))
      |> assert_has(".member-row", text: regular_user.display_name)
      |> assert_has(".member-row", text: to_string(verified_user.email))
    end

    test "narrows the list by email", %{admin_conn: conn, regular_user: regular_user} do
      conn
      |> visit(~p"/admin/users")
      |> fill_in("Search by email", with: "regular_user")
      |> click_button("Search")
      |> assert_has(".member-row", text: regular_user.display_name)
      |> refute_has(".member-row", text: "Verified User")
      |> click_button("Clear")
      |> assert_has(".member-row", text: "Verified User")
    end

    test "says when nobody matches", %{admin_conn: conn} do
      conn
      |> visit(~p"/admin/users")
      |> fill_in("Search by email", with: "nobody@nowhere.example")
      |> click_button("Search")
      |> assert_has("*", text: "No accounts match.")
    end

    test "changes a role from the row menu", %{admin_conn: conn, regular_user: regular_user} do
      conn
      |> visit(~p"/admin/users")
      |> within("[role='menu'][aria-label='Manage Regular User']", fn session ->
        click_button(session, "Make an administrator")
      end)
      |> within("[role='dialog']", &click_button(&1, "Make an administrator"))
      |> assert_has("*", text: "User role updated successfully")
      |> assert_has("section[aria-labelledby='role-admins-heading']", text: "Regular User")

      assert Ash.get!(User, regular_user.id, authorize?: false).role == :admin
    end

    test "offers no menu for the signed-in administrator", %{admin_conn: conn} do
      conn
      |> visit(~p"/admin/users")
      |> refute_has("[role='menu'][aria-label='Manage Admin User']")
    end
  end
end
