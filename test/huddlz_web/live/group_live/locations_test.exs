defmodule HuddlzWeb.GroupLive.LocationsTest do
  use HuddlzWeb.ConnCase, async: true

  import Huddlz.Generator
  import Huddlz.Test.Helpers.LocationSelection
  import Phoenix.LiveViewTest

  describe "locations management page" do
    setup do
      owner = generate(user(role: :user))
      organizer = generate(user(role: :user))
      member = generate(user(role: :user))
      group = generate(group(is_public: true, owner_id: owner.id, actor: owner))

      generate(
        group_member(group_id: group.id, user_id: organizer.id, role: :organizer, actor: owner)
      )

      generate(group_member(group_id: group.id, user_id: member.id, role: :member, actor: owner))

      %{owner: owner, organizer: organizer, member: member, group: group}
    end

    test "owner can access the page", %{conn: conn, owner: owner, group: group} do
      conn
      |> login(owner)
      |> visit(~p"/groups/#{group.slug}/locations")
      |> assert_has("h1", text: "Saved Locations")
    end

    test "page is wrapped in the v3 sidebar shell", %{conn: conn, owner: owner, group: group} do
      # Guards against accidentally reverting `on_mount {LiveUserAuth, :app}`
      # or losing the `<Layouts.app>` wrapper — both regressions would put
      # us back on legacy chrome with no sidebar/topbar.
      conn
      |> login(owner)
      |> visit(~p"/groups/#{group.slug}/locations")
      |> assert_has("aside.sidebar")
      |> assert_has(".content-topbar")
    end

    test "organizer can access the page", %{conn: conn, organizer: organizer, group: group} do
      conn
      |> login(organizer)
      |> visit(~p"/groups/#{group.slug}/locations")
      |> assert_has("h1", text: "Saved Locations")
    end

    test "regular member is redirected", %{conn: conn, member: member, group: group} do
      session =
        conn
        |> login(member)
        |> visit(~p"/groups/#{group.slug}/locations")

      assert_path(session, ~p"/groups/#{group.slug}")
    end

    test "lists saved locations", %{conn: conn, owner: owner, group: group} do
      generate(
        group_location(
          group_id: group.id,
          name: "Community Center",
          address: "100 Main St, Austin, TX",
          actor: owner
        )
      )

      generate(
        group_location(
          group_id: group.id,
          name: "City Park",
          address: "200 Park Ave, Austin, TX",
          actor: owner
        )
      )

      conn
      |> login(owner)
      |> visit(~p"/groups/#{group.slug}/locations")
      |> assert_has("*", text: "Community Center")
      |> assert_has("*", text: "100 Main St, Austin, TX")
      |> assert_has("*", text: "City Park")
      |> assert_has("*", text: "200 Park Ave, Austin, TX")
    end

    test "shows empty state when no locations", %{conn: conn, owner: owner, group: group} do
      conn
      |> login(owner)
      |> visit(~p"/groups/#{group.slug}/locations")
      |> assert_has("*", text: "No saved locations yet")
    end

    test "opens and cancels a styled deletion dialog without changing the location", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      location =
        generate(
          group_location(
            group_id: group.id,
            name: "Old Venue",
            address: "999 Old St, Austin, TX",
            actor: owner
          )
        )

      {:ok, view, _html} =
        conn
        |> login(owner)
        |> live(~p"/groups/#{group.slug}/locations")

      assert has_element?(view, "*", "Old Venue")

      view
      |> element("#open-delete-location-#{location.id}")
      |> render_click()

      assert has_element?(view, "#delete-location-modal [role='dialog']")
      assert has_element?(view, "#delete-location-modal-title", "Delete this saved location?")
      assert has_element?(view, "#delete-location-modal", "Old Venue")
      assert has_element?(view, "#delete-location-modal", "999 Old St, Austin, TX")

      refute has_element?(
               view,
               "#open-delete-location-#{location.id}[data-confirm]"
             )

      view
      |> element("#cancel-delete-location")
      |> render_click()

      refute has_element?(view, "#delete-location-modal")
      assert has_element?(view, "*", "Old Venue")
    end

    test "confirms deletion of an unreferenced location", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      location =
        generate(
          group_location(
            group_id: group.id,
            name: "Disposable Venue",
            address: "999 Old St, Austin, TX",
            actor: owner
          )
        )

      {:ok, view, _html} =
        conn
        |> login(owner)
        |> live(~p"/groups/#{group.slug}/locations")

      view
      |> element("#open-delete-location-#{location.id}")
      |> render_click()

      assert has_element?(
               view,
               "#delete-location-modal",
               "It will no longer appear in future venue pickers"
             )

      view
      |> element("#confirm-delete-location")
      |> render_click()

      refute has_element?(view, "*", "Disposable Venue")
      assert render(view) =~ "Location deleted"
    end

    test "blocks deletion while an upcoming huddl uses the saved location", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      location =
        generate(
          group_location(
            group_id: group.id,
            name: "Scheduled Venue",
            address: "100 Future St, Austin, TX",
            actor: owner
          )
        )

      generate(
        huddl_at_location(
          group_id: group.id,
          creator_id: owner.id,
          group_location_id: location.id,
          physical_location: location.address,
          latitude: location.latitude,
          longitude: location.longitude,
          starts_at: DateTime.add(DateTime.utc_now(), 1, :day),
          ends_at: DateTime.add(DateTime.utc_now(), 1, :day)
        )
      )

      {:ok, view, _html} =
        conn
        |> login(owner)
        |> live(~p"/groups/#{group.slug}/locations")

      view
      |> element("#open-delete-location-#{location.id}")
      |> render_click()

      assert has_element?(
               view,
               "#delete-location-modal",
               "This location is used by 1 current or upcoming huddl"
             )

      assert has_element?(view, "#confirm-delete-location[disabled]")
      assert has_element?(view, "*", "Scheduled Venue")
    end

    test "handles a location deleted concurrently while its dialog is open", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      location =
        generate(
          group_location(
            group_id: group.id,
            name: "Concurrent Venue",
            actor: owner
          )
        )

      {:ok, view, _html} =
        conn
        |> login(owner)
        |> live(~p"/groups/#{group.slug}/locations")

      view
      |> element("#open-delete-location-#{location.id}")
      |> render_click()

      assert :ok = Huddlz.Communities.delete_group_location(location, actor: owner)

      view
      |> element("#confirm-delete-location")
      |> render_click()

      refute has_element?(view, "#delete-location-modal")
      refute has_element?(view, "*", "Concurrent Venue")
      assert render(view) =~ "Location was already deleted"
    end

    test "blank rename stays open with an associated model error", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      location =
        generate(
          group_location(
            group_id: group.id,
            name: "Community Center",
            address: "100 Main St, Austin, TX",
            actor: owner
          )
        )

      {:ok, view, _html} =
        conn
        |> login(owner)
        |> live(~p"/groups/#{group.slug}/locations")

      view
      |> element("button[phx-click='start_rename'][phx-value-id='#{location.id}']")
      |> render_click()

      view
      |> form("#location-rename-form", %{"rename" => %{"name" => ""}})
      |> render_submit()

      assert has_element?(
               view,
               "#rename_name:not([value])[aria-invalid='true'][aria-describedby='rename_name-error-0']"
             )

      assert has_element?(
               view,
               "#rename_name-error-0[role='alert']",
               "Name is required"
             )

      assert has_element?(view, "#location-rename-form")

      assert {:ok, [reloaded]} =
               Huddlz.Communities.list_group_locations(group.id, actor: owner)

      assert reloaded.name == "Community Center"
    end

    test "add address modal opens via patch", %{conn: conn, owner: owner, group: group} do
      {:ok, view, _html} =
        conn
        |> login(owner)
        |> live(~p"/groups/#{group.slug}/locations")

      # Click the "Add Address" link — it's a live_patch
      view
      |> element("a", "Add Address")
      |> render_click()

      # Modal should now be visible
      assert has_element?(view, "#new-location-modal")
      assert has_element?(view, "h2", "Add New Address")
    end

    test "add address modal renders autocomplete inside a form", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      {:ok, view, _html} =
        conn
        |> login(owner)
        |> live(~p"/groups/#{group.slug}/locations/new")

      # Modal should be visible
      assert has_element?(view, "#new-location-modal")

      # The autocomplete input must be inside a form (this is what was broken)
      html = render(view)
      assert html =~ ~s(data-testid="location-input")
      assert html =~ ~s(phx-submit="save_new_location")
    end

    test "saving a new location via the modal", %{conn: conn, owner: owner, group: group} do
      {:ok, view, _html} =
        conn
        |> login(owner)
        |> live(~p"/groups/#{group.slug}/locations/new")

      # Simulate LocationAutocomplete selecting a place
      select_location(view,
        id: "modal-address-autocomplete",
        display_text: "123 Main St, Austin, TX",
        main_text: "123 Main St"
      )

      # Save button should now be enabled and name pre-populated
      assert has_element?(view, "input#location-name-input[value='123 Main St']")

      # Submit the form
      view
      |> element("form[phx-submit='save_new_location']")
      |> render_submit()

      # Should patch back to locations index (not a redirect)
      assert_patched(view, ~p"/groups/#{group.slug}/locations")

      # Verify the location was created
      {:ok, locations} =
        Huddlz.Communities.list_group_locations(group.id, actor: owner)

      assert length(locations) == 1
      assert hd(locations).name == "123 Main St"
    end
  end
end
