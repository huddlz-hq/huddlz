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
      |> assert_has("h2", text: to_string(public_group.name))
      |> refute_has("a", text: "New Group")
    end

    test "renders default rich link preview metadata", %{conn: conn} do
      html =
        conn
        |> get(~p"/groups")
        |> html_response(200)

      assert meta_content(html, ~s(meta[name="description"])) ==
               "Find and join local community gatherings on huddlz."

      assert meta_content(html, ~s(meta[property="og:type"])) == "website"
      assert meta_content(html, ~s(meta[property="og:title"])) == "Groups"

      assert meta_content(html, ~s(meta[property="og:description"])) ==
               "Find and join local community gatherings on huddlz."

      assert meta_content(html, ~s(meta[name="twitter:card"])) == "summary"
      assert meta_content(html, ~s(meta[property="og:image"])) == nil
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

  describe "Index personal sections" do
    setup do
      owner = generate(user(role: :user))
      member = generate(user(role: :user))
      stranger = generate(user(role: :user))

      hosted = generate(group(name: "Cyberpunk Builders", actor: owner, is_public: true))

      joined =
        generate(group(name: "Phoenix Devs", actor: stranger, is_public: true))

      generate(group_member(group_id: joined.id, user_id: member.id, actor: stranger))

      %{owner: owner, member: member, stranger: stranger, hosted: hosted, joined: joined}
    end

    test "anonymous users see no personal sections", %{conn: conn} do
      conn
      |> visit(~p"/groups")
      |> refute_has("span", text: "// Hosting")
      |> refute_has("span", text: "// Joined")
    end

    test "logged-in user with no relationships sees no personal sections", %{conn: conn} do
      disconnected = generate(user(role: :user))

      conn
      |> login(disconnected)
      |> visit(~p"/groups")
      |> refute_has("span", text: "// Hosting")
      |> refute_has("span", text: "// Joined")
    end

    test "owner sees Hosting section with their group", %{
      conn: conn,
      owner: owner,
      hosted: hosted
    } do
      conn
      |> login(owner)
      |> visit(~p"/groups")
      |> assert_has("span", text: "// Hosting")
      |> assert_has("h2", text: to_string(hosted.name))
    end

    test "member sees Joined section with the joined group, not Hosting", %{
      conn: conn,
      member: member,
      joined: joined
    } do
      conn
      |> login(member)
      |> visit(~p"/groups")
      |> assert_has("span", text: "// Joined")
      |> refute_has("span", text: "// Hosting")
      |> assert_has("h2", text: to_string(joined.name))
    end

    test "owner is not double-counted in Joined section", %{conn: conn, owner: owner} do
      # Owner is auto-added as member of their own group. The Joined section
      # filter must exclude groups they own so they only appear under Hosting.
      conn
      |> login(owner)
      |> visit(~p"/groups")
      |> assert_has("span", text: "// Hosting")
      |> refute_has("span", text: "// Joined")
    end

    test "search filters sections and main grid together", %{
      conn: conn,
      owner: owner,
      hosted: hosted
    } do
      _other =
        generate(
          group(name: "Knitting Circle", actor: generate(user(role: :user)), is_public: true)
        )

      session =
        conn
        |> login(owner)
        |> visit(~p"/groups?q=cyberpunk")

      session
      |> assert_has("h2", text: to_string(hosted.name))
      |> refute_has("h2", text: "Knitting Circle")
    end

    test "?yours=hosting scope shows only hosted, hides sections", %{
      conn: conn,
      owner: owner,
      hosted: hosted
    } do
      conn
      |> login(owner)
      |> visit(~p"/groups?yours=hosting")
      |> assert_has("h1", text: "Groups You Host")
      |> assert_has("h2", text: to_string(hosted.name))
      |> refute_has("span", text: "// Hosting")
      |> refute_has("span", text: "// Joined")
      |> assert_has("a", text: "All groups")
    end

    test "?yours=joined scope shows only joined", %{
      conn: conn,
      member: member,
      joined: joined
    } do
      conn
      |> login(member)
      |> visit(~p"/groups?yours=joined")
      |> assert_has("h1", text: "Groups You've Joined")
      |> assert_has("h2", text: to_string(joined.name))
    end

    test "scoped view with non-matching search shows search-aware empty copy", %{
      conn: conn,
      owner: owner
    } do
      # Owner DOES host groups, but the search matches none of them. The empty
      # state must reflect the search, not falsely claim they host nothing.
      conn
      |> login(owner)
      |> visit(~p"/groups?yours=hosting&q=zzznomatch")
      |> assert_has("p", text: "No groups match your search.")
      |> refute_has("p", text: "You aren't hosting any groups yet.")
    end

    test "View all link points to scoped path and preserves search", %{conn: conn} do
      heavy_owner = generate(user(role: :user))

      for i <- 1..7 do
        generate(group(name: "Heavy Group #{i}", actor: heavy_owner, is_public: true))
      end

      # No search active — link should point at the scope only
      conn
      |> login(heavy_owner)
      |> visit(~p"/groups")
      |> assert_has(~s|a[href="/groups?yours=hosting"]|, text: "View all →")

      # Search active — link should preserve the query
      conn
      |> login(heavy_owner)
      |> visit(~p"/groups?q=heavy")
      |> assert_has(~s|a[href="/groups?yours=hosting&q=heavy"]|, text: "View all →")
    end

    test "search with no matches collapses both personal sections", %{
      conn: conn,
      owner: owner
    } do
      # Owner has hosting; also make them a member of an unrelated group so we
      # can prove BOTH sections collapse when the search matches nothing.
      stranger = generate(user(role: :user))
      other_group = generate(group(name: "Knitting Circle", actor: stranger, is_public: true))
      generate(group_member(group_id: other_group.id, user_id: owner.id, actor: stranger))

      conn
      |> login(owner)
      |> visit(~p"/groups?q=zzzznosuchgroupzzzz")
      |> refute_has("span", text: "// Hosting")
      |> refute_has("span", text: "// Joined")
      |> assert_has("p", text: "No groups match your search.")
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
      |> assert_has("label", text: "Group Image")
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
        |> check("Public group (visible to everyone)")

      # Simulate location selection via modal
      view = session.view

      Phoenix.LiveViewTest.render_patch(view, ~p"/groups/new/locations/new")

      send(
        view.pid,
        {:location_selected, "modal-location-autocomplete",
         %{
           place_id: "test_place_id",
           display_text: "Test City, TX, USA",
           main_text: "Test City",
           latitude: 30.27,
           longitude: -97.74
         }}
      )

      Phoenix.LiveViewTest.render(view)
      Phoenix.LiveViewTest.render_submit(view, "select_modal_location", %{})

      session
      |> click_button("Create Group")

      # Verify group was created
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
      |> assert_has("h1", text: to_string(group.name))
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
      |> assert_has("span", text: "Private")
      |> assert_has("span", text: "Owner")
    end

    test "handles non-existent group", %{conn: conn} do
      session = conn |> visit(~p"/groups/#{Ash.UUID.generate()}")

      assert_path(session, ~p"/groups")
      assert Phoenix.Flash.get(session.conn.assigns.flash, :error) =~ "Group not found"
    end
  end
end
