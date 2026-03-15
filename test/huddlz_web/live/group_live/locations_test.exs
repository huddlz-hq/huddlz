defmodule HuddlzWeb.GroupLive.LocationsTest do
  use HuddlzWeb.ConnCase, async: true

  import Huddlz.Generator
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

    test "can delete a location", %{conn: conn, owner: owner, group: group} do
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
      |> element("button[phx-click='delete_location'][phx-value-id='#{location.id}']")
      |> render_click()

      refute has_element?(view, "*", "Old Venue")
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
      send(
        view.pid,
        {:location_selected, "modal-address-autocomplete",
         %{
           place_id: "ChIJ_test",
           display_text: "123 Main St, Austin, TX",
           main_text: "123 Main St",
           latitude: 30.27,
           longitude: -97.74
         }}
      )

      render(view)

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
