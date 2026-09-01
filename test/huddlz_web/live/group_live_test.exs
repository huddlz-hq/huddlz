defmodule HuddlzWeb.GroupLiveTest do
  use HuddlzWeb.ConnCase, async: true

  import Huddlz.Generator
  import Huddlz.Test.Helpers.LocationSelection
  import Phoenix.LiveViewTest

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
      |> assert_has(".row-title", text: "Public group")
    end

    test "exposes group visibility as a labeled keyboard-operable switch", %{
      conn: conn,
      verified: verified
    } do
      {:ok, view, _html} =
        conn
        |> login(verified)
        |> live(~p"/groups/new")

      assert has_element?(
               view,
               ".toggle input[name='form[is_public]'][type='checkbox'][role='switch'][aria-checked='true'][checked]"
             )

      view
      |> form("#group-form", %{"form" => %{"is_public" => "false"}})
      |> render_change()

      assert has_element?(
               view,
               ".toggle input[name='form[is_public]'][role='switch'][aria-checked='false']:not([checked])"
             )
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

      session
      |> select_location(display_text: "Test City, TX, USA", main_text: "Test City")
      |> assert_has("#group-time-zone-derived[data-time-zone='America/Chicago']")
      |> refute_has("#group-time-zone input")
      |> click_button("Create group")

      group =
        Group
        |> Ash.Query.filter(name: "Test Group")
        |> Ash.read_one!()

      assert group.location == "Test City, TX, USA"
      assert group.latitude == 30.27
      assert group.longitude == -97.74
    end

    @tag issue403: true
    test "requires a city whose time zone resolves without offering a manual override", %{
      conn: conn,
      verified: verified
    } do
      session =
        conn
        |> login(verified)
        |> visit(~p"/groups/new")

      Mox.stub(Huddlz.MockLocationTimeZone, :resolve, fn latitude, longitude ->
        assert latitude == 0.0
        assert longitude == 0.0
        {:error, :not_found}
      end)

      Mox.allow(Huddlz.MockLocationTimeZone, self(), session.view.pid)

      session
      |> select_location(display_text: "Unknown city", latitude: 0.0, longitude: 0.0)
      |> assert_has(
        "#group-time-zone-resolution-error",
        text: "Choose a city whose time zone can be resolved"
      )
      |> refute_has("#group-time-zone")
      |> fill_in("Group name", with: "Unresolved City Group")
      |> click_button("Create group")
      |> assert_path(~p"/groups/new")
      |> assert_has("#group-time-zone-resolution-error", text: "time zone can be resolved")

      refute Group
             |> Ash.Query.filter(name == "Unresolved City Group")
             |> Ash.exists?()
    end

    test "shows errors with invalid data", %{conn: conn, verified: verified} do
      session =
        conn
        |> login(verified)
        |> visit(~p"/groups/new")
        |> fill_in("Group name", with: "")
        |> fill_in("Description", with: "Missing name")
        |> click_button("Create group")

      session
      |> assert_has(
        "input[name='form[name]'][aria-invalid='true'][aria-describedby='form_name-help form_name-error-0']"
      )
      |> assert_has("#form_name-help", text: "3–100 characters.")
      |> assert_has("#form_name-error-0", text: "is required")
    end

    test "validates on change", %{conn: conn, verified: verified} do
      session =
        conn
        |> login(verified)
        |> visit(~p"/groups/new")
        |> fill_in("Group name", with: "ab")

      session
      |> assert_has(
        "input[name='form[name]'][aria-invalid='true'][aria-describedby='form_name-help form_name-error-0']"
      )
      |> assert_has("#form_name-error-0", text: "Must be between 3 and 100 characters")
    end

    test "validates both group name boundaries in the LiveView", %{
      conn: conn,
      verified: verified
    } do
      session =
        conn
        |> login(verified)
        |> visit(~p"/groups/new")
        |> fill_in("Group name", with: "abc")
        |> refute_has("#form_name-error-0")
        |> fill_in("Group name", with: String.duplicate("a", 100))
        |> refute_has("#form_name-error-0")
        |> fill_in("Group name", with: String.duplicate("a", 101))

      assert_has(
        session,
        "#form_name-error-0",
        text: "Must be between 3 and 100 characters"
      )
    end

    test "associates help text without marking valid fields invalid", %{
      conn: conn,
      verified: verified
    } do
      session =
        conn
        |> login(verified)
        |> visit(~p"/groups/new")

      session
      |> assert_has("input[name='form[name]'][aria-describedby='form_name-help']")
      |> refute_has("input[name='form[name]'][aria-invalid='true']")
    end

    test "shows location error when submitting with a location that is too long", %{
      conn: conn,
      verified: verified
    } do
      session =
        conn
        |> login(verified)
        |> visit(~p"/groups/new")
        |> fill_in("Group name", with: "Test Group")
        |> fill_in("Description", with: "A test group description")

      session
      |> select_location(display_text: String.duplicate("x", 501), main_text: "Too Long")
      |> click_button("Create group")
      |> assert_path(~p"/groups/new")
      |> assert_has("p.form-error", text: "length must be less than or equal to 500")
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

    test "does not list draft huddlz on the group page", %{
      conn: conn,
      owner: owner,
      public_group: group
    } do
      generate(
        huddl(
          title: "Private Draft",
          group_id: group.id,
          creator_id: owner.id,
          lifecycle_state: :draft,
          actor: owner
        )
      )

      conn
      |> login(owner)
      |> visit(~p"/groups/#{group.slug}")
      |> refute_has("h3", text: "Private Draft")
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

    test "private groups are indistinguishable from missing groups", %{
      conn: conn,
      non_member: non_member,
      private_group: group
    } do
      assert {404, _headers, body} =
               assert_error_sent(404, fn ->
                 conn
                 |> login(non_member)
                 |> get(~p"/groups/#{group.slug}")
               end)

      assert body =~ "This path doesn’t lead to a huddl."
      refute body =~ to_string(group.name)
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
      assert {404, _headers, body} =
               assert_error_sent(404, fn ->
                 get(conn, ~p"/groups/#{Ash.UUID.generate()}")
               end)

      assert body =~ "This path doesn’t lead to a huddl."
    end
  end
end
