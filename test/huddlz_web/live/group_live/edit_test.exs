defmodule HuddlzWeb.GroupLive.EditTest do
  use HuddlzWeb.ConnCase, async: true

  import Huddlz.Generator

  describe "Edit Group" do
    setup do
      owner = generate(user(role: :verified))
      non_owner = generate(user(role: :verified))

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
      conn
      |> login(owner)
      |> visit(~p"/groups/#{group.slug}/edit")
      |> fill_in("Group Name", with: "Updated Group Name")
      |> fill_in("Description", with: "Updated description", exact: false)
      |> fill_in("Location", with: "Updated location")
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
  end
end
