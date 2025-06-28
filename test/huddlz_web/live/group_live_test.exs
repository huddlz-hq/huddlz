defmodule HuddlzWeb.GroupLiveTest do
  use HuddlzWeb.ConnCase, async: true

  import Huddlz.Generator

  alias Huddlz.Communities.Group

  require Ash.Query

  describe "Index" do
    setup do
      admin = generate(user(role: :admin))
      verified = generate(user(role: :user))
      regular = generate(user(role: :user))

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
      conn
      |> visit(~p"/groups")
      |> assert_has("h1", text: "Groups")
      |> assert_has("h2.card-title", text: to_string(public_group.name))
      |> refute_has("a", text: "New Group")
    end

    test "shows New Group button for users", %{conn: conn, verified: verified} do
      conn
      |> login(verified)
      |> visit(~p"/groups")
      |> assert_has("a", text: "New Group")
    end

    test "shows New Group button for admin users", %{conn: conn, admin: admin} do
      conn
      |> login(admin)
      |> visit(~p"/groups")
      |> assert_has("a", text: "New Group")
    end

    test "shows New Group button for all users", %{conn: conn, regular: regular} do
      conn
      |> login(regular)
      |> visit(~p"/groups")
      |> assert_has("a", text: "New Group")
    end

    test "navigates to new group page", %{conn: conn, verified: verified} do
      conn
      |> login(verified)
      |> visit(~p"/groups")
      |> click_link("New Group")
      |> assert_has("h1", text: "Create a New Group")
    end
  end

  describe "New" do
    setup do
      admin = generate(user(role: :admin))
      verified = generate(user(role: :user))
      regular = generate(user(role: :user))

      %{admin: admin, verified: verified, regular: regular}
    end

    test "renders form for users", %{conn: conn, verified: verified} do
      conn
      |> login(verified)
      |> visit(~p"/groups/new")
      |> assert_has("h1", text: "Create a New Group")
      |> assert_has("label", text: "Group Name")
      |> assert_has("label", text: "Description")
      |> assert_has("label", text: "Location")
      |> assert_has("label", text: "Image URL")
      |> assert_has("label", text: "Privacy")
    end

    test "allows all users to create groups", %{conn: conn, regular: regular} do
      conn
      |> login(regular)
      |> visit(~p"/groups/new")
      |> assert_has("h1", text: "Create a New Group")
    end

    test "creates group with valid data", %{conn: conn, verified: verified} do
      session =
        conn
        |> login(verified)
        |> visit(~p"/groups/new")
        |> fill_in("Group Name", with: "Test Group")
        |> fill_in("Description", with: "A test group")
        |> fill_in("Location", with: "Test City")
        |> check("Public group (visible to everyone)")
        |> click_button("Create Group")

      # Verify group was created
      group =
        Group
        |> Ash.Query.filter(name: "Test Group")
        |> Ash.read_one!()

      assert_path(session, ~p"/groups/#{group.slug}")
    end

    test "shows errors with invalid data", %{conn: conn, verified: verified} do
      conn
      |> login(verified)
      |> visit(~p"/groups/new")
      |> fill_in("Group Name", with: "")
      |> fill_in("Description", with: "Missing name")
      |> click_button("Create Group")
      |> assert_has("p", text: "is required")
    end

    test "validates on change", %{conn: conn, verified: verified} do
      conn
      |> login(verified)
      |> visit(~p"/groups/new")
      |> fill_in("Group Name", with: "ab")
      # PhoenixTest triggers phx-change automatically when filling fields
      |> assert_has("p", text: "length must be greater than or equal to")
    end
  end

  describe "Show" do
    setup do
      owner = generate(user(role: :user))
      member = generate(user(role: :user))
      non_member = generate(user(role: :user))

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
      conn
      |> visit(~p"/groups/#{group.slug}")
      |> assert_has("h1", text: to_string(group.name))
      |> assert_has("span", text: "Public Group")
      |> assert_has("p", text: to_string(group.description))
      |> assert_has("p", text: group.location)
      # No edit button for anonymous
      |> refute_has("a", text: "Edit Group")
    end

    test "displays owner badge for group owner", %{
      conn: conn,
      owner: owner,
      public_group: group
    } do
      conn
      |> login(owner)
      |> visit(~p"/groups/#{group.slug}")
      |> assert_has("span", text: "Owner")
    end

    test "redirects non-members from private groups", %{
      conn: conn,
      non_member: non_member,
      private_group: group
    } do
      session =
        conn
        |> login(non_member)
        |> visit(~p"/groups/#{group.slug}")

      assert_path(session, ~p"/groups")

      assert Phoenix.Flash.get(session.conn.assigns.flash, :error) =~
               "Group not found"
    end

    test "allows owner to view private group", %{
      conn: conn,
      owner: owner,
      private_group: group
    } do
      conn
      |> login(owner)
      |> visit(~p"/groups/#{group.slug}")
      |> assert_has("h1", text: to_string(group.name))
      |> assert_has("span", text: "Private Group")
      |> assert_has("span", text: "Owner")
    end

    test "handles non-existent group", %{conn: conn} do
      session = conn |> visit(~p"/groups/#{Ash.UUID.generate()}")

      assert_path(session, ~p"/groups")
      assert Phoenix.Flash.get(session.conn.assigns.flash, :error) =~ "Group not found"
    end

    test "navigates back to groups index", %{
      conn: conn,
      public_group: group
    } do
      conn
      |> visit(~p"/groups/#{group.slug}")
      |> click_link("Back to groups")
      |> assert_has("h1", text: "Groups")
    end
  end
end
