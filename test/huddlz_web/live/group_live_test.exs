defmodule HuddlzWeb.GroupLiveTest do
  use HuddlzWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Huddlz.Generator

  alias Huddlz.Communities.Group

  require Ash.Query

  describe "Index" do
    setup do
      admin = generate(user(role: :admin))
      verified = generate(user(role: :verified))
      regular = generate(user(role: :regular))

      public_group = generate(group(is_public: true, owner_id: verified.id, actor: verified))
      private_group = generate(group(is_public: false, owner_id: admin.id, actor: admin))

      %{
        admin: admin,
        verified: verified,
        regular: regular,
        public_group: public_group,
        private_group: private_group
      }
    end

    test "lists public groups for anonymous users", %{conn: conn, public_group: public_group} do
      {:ok, _index_live, html} = live(conn, ~p"/groups")

      assert html =~ "Groups"
      assert html =~ to_string(public_group.name)
      refute html =~ "New Group"
    end

    test "shows New Group button for verified users", %{conn: conn, verified: verified} do
      {:ok, _index_live, html} =
        conn
        |> login(verified)
        |> live(~p"/groups")

      assert html =~ "New Group"
    end

    test "shows New Group button for admin users", %{conn: conn, admin: admin} do
      {:ok, _index_live, html} =
        conn
        |> login(admin)
        |> live(~p"/groups")

      assert html =~ "New Group"
    end

    test "does not show New Group button for regular users", %{conn: conn, regular: regular} do
      {:ok, _index_live, html} =
        conn
        |> login(regular)
        |> live(~p"/groups")

      refute html =~ "New Group"
    end

    test "navigates to new group page", %{conn: conn, verified: verified} do
      {:ok, index_live, _html} =
        conn
        |> login(verified)
        |> live(~p"/groups")

      # Need to pass the authenticated conn for the redirect
      authenticated_conn = login(conn, verified)

      assert {:ok, _new_live, html} =
               index_live
               |> element("a", "New Group")
               |> render_click()
               |> follow_redirect(authenticated_conn, ~p"/groups/new")

      assert html =~ "Create a New Group"
    end
  end

  describe "New" do
    setup do
      admin = generate(user(role: :admin))
      verified = generate(user(role: :verified))
      regular = generate(user(role: :regular))

      %{admin: admin, verified: verified, regular: regular}
    end

    test "renders form for verified users", %{conn: conn, verified: verified} do
      {:ok, _new_live, html} =
        conn
        |> login(verified)
        |> live(~p"/groups/new")

      assert html =~ "Create a New Group"
      assert html =~ "Group Name"
      assert html =~ "Description"
      assert html =~ "Location"
      assert html =~ "Image URL"
      assert html =~ "Privacy"
    end

    test "redirects regular users", %{conn: conn, regular: regular} do
      {:error, {:redirect, %{to: path, flash: flash}}} =
        conn
        |> login(regular)
        |> live(~p"/groups/new")

      assert path == ~p"/groups"
      assert flash["error"] =~ "You need to be a verified user to create groups"
    end

    test "creates group with valid data", %{conn: conn, verified: verified} do
      {:ok, new_live, _html} =
        conn
        |> login(verified)
        |> live(~p"/groups/new")

      assert new_live
             |> form("#group-form", %{
               "form" => %{
                 "name" => "Test Group",
                 "description" => "A test group",
                 "location" => "Test City",
                 "is_public" => "true"
               }
             })
             |> render_submit()

      # Verify group was created
      group =
        Group
        |> Ash.Query.filter(name: "Test Group")
        |> Ash.read_one!()

      assert_redirect(new_live, ~p"/groups/#{group.id}")
    end

    test "shows errors with invalid data", %{conn: conn, verified: verified} do
      {:ok, new_live, _html} =
        conn
        |> login(verified)
        |> live(~p"/groups/new")

      assert new_live
             |> form("#group-form", %{
               "form" => %{
                 "name" => "",
                 "description" => "Missing name"
               }
             })
             |> render_submit() =~ "is required"
    end

    test "validates on change", %{conn: conn, verified: verified} do
      {:ok, new_live, _html} =
        conn
        |> login(verified)
        |> live(~p"/groups/new")

      assert new_live
             |> form("#group-form", %{
               "form" => %{
                 # Too short (min 3 chars)
                 "name" => "ab"
               }
             })
             |> render_change() =~ "length must be greater than or equal to"
    end
  end

  describe "Show" do
    setup do
      owner = generate(user(role: :verified))
      member = generate(user(role: :regular))
      non_member = generate(user(role: :regular))

      public_group =
        generate(
          group(
            is_public: true,
            owner_id: owner.id,
            name: "Public Test Group",
            description: "A public group for testing",
            location: "Test Location",
            actor: owner
          )
        )

      private_group =
        generate(
          group(
            is_public: false,
            owner_id: owner.id,
            name: "Private Test Group",
            actor: owner
          )
        )

      %{
        owner: owner,
        member: member,
        non_member: non_member,
        public_group: public_group,
        private_group: private_group
      }
    end

    test "displays public group details for anonymous users", %{
      conn: conn,
      public_group: group
    } do
      {:ok, _show_live, html} = live(conn, ~p"/groups/#{group.id}")

      assert html =~ to_string(group.name)
      assert html =~ "Public Group"
      assert html =~ to_string(group.description)
      assert html =~ group.location
      # No edit button for anonymous
      refute html =~ "Edit Group"
    end

    test "displays owner badge for group owner", %{
      conn: conn,
      owner: owner,
      public_group: group
    } do
      {:ok, _show_live, html} =
        conn
        |> login(owner)
        |> live(~p"/groups/#{group.id}")

      assert html =~ "Owner"
    end

    test "redirects non-members from private groups", %{
      conn: conn,
      non_member: non_member,
      private_group: group
    } do
      {:error, {:redirect, %{to: path, flash: flash}}} =
        conn
        |> login(non_member)
        |> live(~p"/groups/#{group.id}")

      assert path == ~p"/groups"
      assert flash["error"] =~ "You don't have access to this private group"
    end

    test "allows owner to view private group", %{
      conn: conn,
      owner: owner,
      private_group: group
    } do
      {:ok, _show_live, html} =
        conn
        |> login(owner)
        |> live(~p"/groups/#{group.id}")

      assert html =~ to_string(group.name)
      assert html =~ "Private Group"
      assert html =~ "Owner"
    end

    test "handles non-existent group", %{conn: conn} do
      {:error, {:redirect, %{to: path, flash: flash}}} =
        live(conn, ~p"/groups/#{Ash.UUID.generate()}")

      assert path == ~p"/groups"
      assert flash["error"] =~ "Group not found"
    end

    test "navigates back to groups index", %{
      conn: conn,
      public_group: group
    } do
      {:ok, show_live, _html} = live(conn, ~p"/groups/#{group.id}")

      assert {:ok, _index_live, html} =
               show_live
               |> element("a", "Back to groups")
               |> render_click()
               |> follow_redirect(conn, ~p"/groups")

      assert html =~ "Groups"
    end
  end
end
