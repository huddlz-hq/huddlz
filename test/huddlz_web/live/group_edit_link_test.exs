defmodule HuddlzWeb.GroupEditLinkTest do
  use HuddlzWeb.ConnCase, async: true

  import Huddlz.Generator

  describe "Edit Group link on show page" do
    setup do
      owner = generate(user(role: :verified))
      member = generate(user(role: :verified))

      group =
        generate(
          group(
            owner_id: owner.id,
            name: "Test Group",
            slug: "test-group",
            is_public: true,
            actor: owner
          )
        )

      %{owner: owner, member: member, group: group}
    end

    test "owner sees Edit Group link", %{conn: conn, owner: owner, group: group} do
      conn
      |> login(owner)
      |> visit(~p"/groups/#{group.slug}")
      |> assert_has("a", text: "Edit Group")
      |> click_link("Edit Group")
      |> assert_has("h1", text: "Edit Group")
    end

    test "non-owner does not see Edit Group link", %{conn: conn, member: member, group: group} do
      conn
      |> login(member)
      |> visit(~p"/groups/#{group.slug}")
      |> refute_has("a", text: "Edit Group")
    end

    test "Edit Group button is no longer a modal trigger", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      # Verify the old modal-related attributes are gone
      conn
      |> login(owner)
      |> visit(~p"/groups/#{group.slug}")
      |> refute_has("button[phx-click='open_edit_modal']")
      |> refute_has("#edit-group-modal")
    end
  end
end
