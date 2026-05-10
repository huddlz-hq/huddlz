defmodule HuddlzWeb.GroupLiveTest do
  use HuddlzWeb.ConnCase, async: true

  import Huddlz.Generator

  alias Huddlz.Communities.Group

  require Ash.Query

  describe "New" do
    setup do
      admin = generate(user(role: :admin))
      verified = generate(user(role: :user))
      regular = generate(user(role: :user))

      %{admin: admin, verified: verified, regular: regular}
    end

    test "renders v3 shell with form panels", %{conn: conn, verified: verified} do
      conn
      |> login(verified)
      |> visit(~p"/groups/new")
      |> assert_has("aside.sidebar")
      |> assert_has("h1", text: "Create a group")
      |> assert_has(".panel .panel-head h2", text: "The basics")
      |> assert_has(".panel .panel-head h2", text: "Cover image")
      |> assert_has(".panel .panel-head h2", text: "Visibility")
      |> assert_has("label.form-label", text: "Group name")
      |> assert_has("label.form-label", text: "Description")
      |> assert_has("label.form-label", text: "Location")
      |> assert_has("label.row-title", text: "Public group")
    end

    test "allows all users to create groups", %{conn: conn, regular: regular} do
      conn
      |> login(regular)
      |> visit(~p"/groups/new")
      |> assert_has("h1", text: "Create a group")
    end

    test "creates group with valid data", %{conn: conn, verified: verified} do
      session =
        conn
        |> login(verified)
        |> visit(~p"/groups/new")
        |> fill_in("Group name", with: "Test Group")
        |> fill_in("Description", with: "A test group")
        |> check("Public group")

      view = session.view

      send(
        view.pid,
        {:location_selected, "group-location",
         %{
           place_id: "test_place_id",
           display_text: "Test City, TX, USA",
           main_text: "Test City",
           latitude: 30.27,
           longitude: -97.74
         }}
      )

      Phoenix.LiveViewTest.render(view)

      session
      |> click_button("Create group")

      group =
        Group
        |> Ash.Query.filter(name: "Test Group")
        |> Ash.read_one!()

      assert group.location == "Test City, TX, USA"
      assert group.latitude == 30.27
      assert group.longitude == -97.74
    end

    test "shows errors with invalid data", %{conn: conn, verified: verified} do
      conn
      |> login(verified)
      |> visit(~p"/groups/new")
      |> fill_in("Group name", with: "")
      |> fill_in("Description", with: "Missing name")
      |> click_button("Create group")
      |> assert_has("p", text: "is required")
    end

    test "validates on change", %{conn: conn, verified: verified} do
      conn
      |> login(verified)
      |> visit(~p"/groups/new")
      |> fill_in("Group name", with: "ab")
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
      |> assert_has(".hero h1", text: to_string(group.name))
      |> assert_has(".huddl-intro p", text: to_string(group.description))
      |> assert_has(".hero .meta span", text: group.location)
      |> assert_has(".facts .value", text: group.location)
      |> refute_has("a", text: "Edit Group")
    end

    test "renders v3 hero and side panel for signed-in members", %{
      conn: conn,
      owner: owner,
      public_group: group
    } do
      conn
      |> login(owner)
      |> visit(~p"/groups/#{group.slug}")
      |> assert_has("aside.sidebar")
      |> assert_has("div.hero .hero-content h1", text: to_string(group.name))
      |> assert_has(".huddl-side h3", text: "This group")
      |> assert_has(".facts .label", text: "Members")
    end

    test "displays owner badge for group owner", %{
      conn: conn,
      owner: owner,
      public_group: group
    } do
      conn
      |> login(owner)
      |> visit(~p"/groups/#{group.slug}")
      |> assert_has(".role-pill .pill", text: "Owner")
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

      assert_path(session, ~p"/discover", query_params: %{"scope" => "groups"})

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
      |> assert_has(".hero h1", text: to_string(group.name))
      |> assert_has(".eyebrow", text: "Private")
      |> assert_has(".role-pill .pill", text: "Owner")
    end

    test "handles non-existent group", %{conn: conn} do
      session = conn |> visit(~p"/groups/#{Ash.UUID.generate()}")

      assert_path(session, ~p"/discover", query_params: %{"scope" => "groups"})
      assert Phoenix.Flash.get(session.conn.assigns.flash, :error) =~ "Group not found"
    end
  end
end
