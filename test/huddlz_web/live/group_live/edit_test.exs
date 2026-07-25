defmodule HuddlzWeb.GroupLive.EditTest do
  use HuddlzWeb.ConnCase, async: true

  import Huddlz.Generator
  import Huddlz.Test.Helpers.LocationSelection
  import Phoenix.LiveViewTest

  describe "Edit Group" do
    setup do
      owner = generate(user(role: :user))
      non_owner = generate(user(role: :user))

      group =
        generate(
          group(
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
      |> assert_has("#group-visibility-current[data-visibility='public']", text: "Public")
      |> assert_has("#group-visibility-selection[data-visibility='public']", text: "Public group")
      |> assert_has(
        "#group-is-public[aria-labelledby='group-visibility-label'][aria-describedby='group-visibility-description group-visibility-consequence']"
      )
      |> assert_has("#group-visibility-consequence", text: "No visibility change pending")
    end

    test "renders v3 chrome with the three panels in order", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      conn
      |> login(owner)
      |> visit(~p"/groups/#{group.slug}/edit")
      |> assert_has("aside.sidebar")
      |> assert_has(".panel:nth-of-type(1) h2", text: "Cover image")
      |> assert_has(".panel:nth-of-type(2) h2", text: "The basics")
      |> assert_has(".panel:nth-of-type(3) h2", text: "Visibility")
      |> assert_has(".slug-control .slug-prefix", text: "huddlz.com/groups/")
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

      session
      |> select_location(
        display_text: "Updated location",
        main_text: "Updated location",
        latitude: 40.71,
        longitude: -74.01
      )
      |> click_button("Save Changes")
      |> assert_has("div[role='alert']", text: "Group updated successfully")
      |> assert_has("h1", text: "Updated Group Name")
      |> assert_has("p", text: "Updated description")
      |> assert_has(".hero .meta span", text: "Updated location")
    end

    test "changing a public group to private explains the consequences", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      conn
      |> login(owner)
      |> visit(~p"/groups/#{group.slug}/edit")
      |> uncheck("Public group")
      |> assert_has("#group-visibility-current[data-visibility='public']", text: "Public")
      |> assert_has("#group-visibility-selection[data-visibility='private']",
        text: "Private group"
      )
      |> assert_has(
        "#group-visibility-description",
        text: "Only current members can access this group and its huddlz"
      )
      |> assert_has(
        "#group-visibility-consequence",
        text: "this group and all existing huddlz will leave public discovery"
      )
      |> assert_has("#group-visibility-consequence",
        text: "Current members keep their memberships"
      )
    end

    test "changing a private group to public explains the consequences", %{
      conn: conn,
      owner: owner
    } do
      private_group =
        generate(
          group(
            name: "Private Test Group",
            slug: "private-test-group",
            is_public: false,
            actor: owner
          )
        )

      conn
      |> login(owner)
      |> visit(~p"/groups/#{private_group.slug}/edit")
      |> assert_has("#group-visibility-current[data-visibility='private']", text: "Private")
      |> check("Private group")
      |> assert_has("#group-visibility-selection[data-visibility='public']", text: "Public group")
      |> assert_has(
        "#group-visibility-description",
        text: "Anyone can find and join this group"
      )
      |> assert_has(
        "#group-visibility-consequence",
        text: "this group and otherwise-public huddlz will become discoverable again"
      )
    end

    test "saving names the new visibility in the success feedback", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      conn
      |> login(owner)
      |> visit(~p"/groups/#{group.slug}/edit")
      |> uncheck("Public group")
      |> click_button("Save Changes")
      |> assert_has(
        "div[role='alert']",
        text: "Group updated successfully. Visibility is now private."
      )
    end

    test "canceling a pending visibility change preserves the saved state", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      conn
      |> login(owner)
      |> visit(~p"/groups/#{group.slug}/edit")
      |> uncheck("Public group")
      |> click_link("Cancel")
      |> visit(~p"/groups/#{group.slug}/edit")
      |> assert_has("#group-visibility-current[data-visibility='public']", text: "Public")
      |> assert_has("#group-visibility-selection[data-visibility='public']", text: "Public group")
    end

    test "slug change shows warning", %{conn: conn, owner: owner, group: group} do
      conn
      |> login(owner)
      |> visit(~p"/groups/#{group.slug}/edit")
      |> fill_in("URL Slug", with: "new-slug")
      |> assert_has("h3", text: "Warning: URL Change")
      |> assert_has(".slug-warn p", text: "Changing the slug will break existing links")
      |> assert_has(".slug-warn span", text: "/groups/test-group")
      |> assert_has(".slug-warn span", text: "/groups/new-slug")
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

    test "shows location error when submitting with a location that is too long", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      session =
        conn
        |> login(owner)
        |> visit(~p"/groups/#{group.slug}/edit")

      session
      |> select_location(display_text: String.duplicate("x", 501), main_text: "Too Long")
      |> click_button("Save Changes")
      |> assert_path(~p"/groups/#{group.slug}/edit")
      |> assert_has("p.form-error", text: "length must be less than or equal to 500")
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

    test "location field uses city/region search, not address search", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      {:ok, _view, html} =
        conn
        |> login(owner)
        |> live(~p"/groups/#{group.slug}/edit")

      refute html =~ "Save Address"
      refute html =~ "Location Name"
    end

    test "can set a new location inline and save", %{conn: conn, owner: owner, group: group} do
      session =
        conn
        |> login(owner)
        |> visit(~p"/groups/#{group.slug}/edit")

      session
      |> select_location()
      |> click_button("Save Changes")
      |> assert_has("div[role='alert']", text: "Group updated successfully")
      |> assert_has(".hero .meta span", text: "Austin, TX, USA")
    end
  end
end
