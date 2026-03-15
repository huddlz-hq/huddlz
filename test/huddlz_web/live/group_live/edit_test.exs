defmodule HuddlzWeb.GroupLive.EditTest do
  use HuddlzWeb.ConnCase, async: true

  import Huddlz.Generator

  describe "Edit Group" do
    setup do
      owner = generate(user(role: :user))
      non_owner = generate(user(role: :user))

      group =
        generate(
          group(
            owner_id: owner.id,
            name: "Test Group",
            slug: "test-group",
            description: "Original description",
            location: "Original location",
            is_public: true,
            actor: owner
          )
        )

      %{owner: owner, non_owner: non_owner, group: group}
    end

    test "owner can access edit page", %{conn: conn, owner: owner, group: group} do
      conn
      |> login(owner)
      |> visit(~p"/groups/#{group.slug}/edit")
      |> assert_has("h1", text: "Edit Group")
      |> assert_has("input[name='form[name]'][value='Test Group']")
      |> assert_has("input[name='form[slug]'][value='test-group']")
    end

    test "non-owner cannot access edit page", %{conn: conn, non_owner: non_owner, group: group} do
      conn
      |> login(non_owner)
      |> visit(~p"/groups/#{group.slug}/edit")
      |> assert_has("div[role='alert']", text: "You don't have permission to edit this group")
    end

    test "owner can update group details", %{conn: conn, owner: owner, group: group} do
      session =
        conn
        |> login(owner)
        |> visit(~p"/groups/#{group.slug}/edit")
        |> fill_in("Group Name", with: "Updated Group Name")
        |> fill_in("Description", with: "Updated description", exact: false)

      # Simulate adding a new location via modal
      view = session.view

      Phoenix.LiveViewTest.render_patch(view, ~p"/groups/#{group.slug}/edit/locations/new")

      send(
        view.pid,
        {:location_selected, "modal-location-autocomplete",
         %{
           place_id: "test_place_id",
           display_text: "Updated location",
           main_text: "Updated location",
           latitude: 40.71,
           longitude: -74.01
         }}
      )

      Phoenix.LiveViewTest.render(view)
      Phoenix.LiveViewTest.render_submit(view, "select_modal_location", %{})

      session
      |> click_button("Save Changes")
      |> assert_has("div[role='alert']", text: "Group updated successfully")
      |> assert_has("h1", text: "Updated Group Name")
      |> assert_has("p", text: "Updated description")
      |> assert_has("p", text: "Updated location")
    end

    test "slug change shows warning", %{conn: conn, owner: owner, group: group} do
      conn
      |> login(owner)
      |> visit(~p"/groups/#{group.slug}/edit")
      |> fill_in("URL Slug", with: "new-slug")
      |> assert_has("h3", text: "Warning: URL Change")
      |> assert_has("p", text: "Changing the slug will break existing links")
      |> assert_has("span", text: "/groups/test-group")
      |> assert_has("span", text: "/groups/new-slug")
    end

    test "updating slug redirects to new URL", %{conn: conn, owner: owner, group: group} do
      conn
      |> login(owner)
      |> visit(~p"/groups/#{group.slug}/edit")
      |> fill_in("URL Slug", with: "new-group-slug")
      |> click_button("Save Changes")
      |> assert_has("div[role='alert']", text: "Group updated successfully")
      # After redirect, we should be on the new slug page
      |> assert_has("h1", text: "Test Group")
    end

    test "cancel button returns to group page", %{conn: conn, owner: owner, group: group} do
      conn
      |> login(owner)
      |> visit(~p"/groups/#{group.slug}/edit")
      |> click_link("Cancel")
      |> assert_has("h1", text: "Test Group")
    end

    test "displays current location with city picker UI", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      # Set coordinates on the group so the location displays
      Ash.Changeset.for_update(group, :update_details, %{location: "Original location"},
        actor: owner
      )
      |> Ash.Changeset.force_change_attribute(:latitude, 37.77)
      |> Ash.Changeset.force_change_attribute(:longitude, -122.42)
      |> Ash.update!()

      conn
      |> login(owner)
      |> visit(~p"/groups/#{group.slug}/edit")
      |> assert_has("label", text: "Location")
      |> assert_has("span", text: "Original location")
      # Should NOT have a SavedLocationPicker dropdown
      |> refute_has("#saved-location-picker-input")
    end

    test "location modal uses city/region search", %{conn: conn, owner: owner, group: group} do
      session =
        conn
        |> login(owner)
        |> visit(~p"/groups/#{group.slug}/edit")

      view = session.view
      Phoenix.LiveViewTest.render_patch(view, ~p"/groups/#{group.slug}/edit/locations/new")

      html = Phoenix.LiveViewTest.render(view)

      # Modal should show city/region search, not address search
      assert html =~ "Search for a city or region"
      assert html =~ "Use This Location"
      refute html =~ "Save Address"
      refute html =~ "Location Name"
    end

    test "can clear and set location via city modal", %{conn: conn, owner: owner, group: group} do
      session =
        conn
        |> login(owner)
        |> visit(~p"/groups/#{group.slug}/edit")

      view = session.view

      # Clear the existing location
      Phoenix.LiveViewTest.render_click(view, "clear_location")
      html = Phoenix.LiveViewTest.render(view)
      assert html =~ "Search for a city or region..."

      # Open modal and select a new city
      Phoenix.LiveViewTest.render_patch(view, ~p"/groups/#{group.slug}/edit/locations/new")

      send(
        view.pid,
        {:location_selected, "modal-location-autocomplete",
         %{
           place_id: "test_place_id",
           display_text: "Austin, TX, USA",
           main_text: "Austin",
           latitude: 30.27,
           longitude: -97.74
         }}
      )

      Phoenix.LiveViewTest.render(view)
      Phoenix.LiveViewTest.render_submit(view, "select_modal_location", %{})

      html = Phoenix.LiveViewTest.render(view)
      assert html =~ "Austin, TX, USA"

      # Save and verify
      session
      |> click_button("Save Changes")
      |> assert_has("div[role='alert']", text: "Group updated successfully")
      |> assert_has("p", text: "Austin, TX, USA")
    end
  end
end
