defmodule HuddlzWeb.GroupLive.ShowTest do
  use HuddlzWeb.ConnCase, async: true

  import Huddlz.Test.Helpers.Authentication

  describe "membership action buttons" do
    setup do
      owner = generate(user(role: :user))

      group =
        generate(
          group(
            owner_id: owner.id,
            is_public: true,
            name: "Membership Test Group",
            actor: owner
          )
        )

      %{owner: owner, group: group}
    end

    test "join button shows a pending state while submitting", %{conn: conn, group: group} do
      visitor = generate(user(role: :user))

      conn
      |> login(visitor)
      |> visit(~p"/groups/#{group.slug}")
      |> assert_has("button[phx-disable-with='Joining...']", text: "Join Group")
    end

    test "leave button opens an in-app confirmation without changing membership", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      member = generate(user(role: :user))

      generate(
        group_member(
          group_id: group.id,
          user_id: member.id,
          role: :member,
          actor: owner
        )
      )

      session =
        conn
        |> login(member)
        |> visit(~p"/groups/#{group.slug}")
        |> refute_has("button[data-confirm]", text: "Leave Group")
        |> click_button("Leave Group")
        |> assert_has("#leave-group-dialog [role='dialog']")
        |> assert_has("#leave-group-dialog-title", text: "Leave Membership Test Group?")
        |> assert_has("#leave-group-dialog", text: "member roster")
        |> assert_has("#leave-group-dialog", text: "My groups")
        |> assert_has("#leave-group-dialog", text: "notifications")
        |> assert_has(
          "#leave-group-dialog-container[phx-key='escape'][phx-window-keydown][phx-click-away]"
        )
        |> assert_has("#leave-group-dialog-cancel", text: "Cancel")

      session
      |> within("#leave-group-dialog", fn session ->
        click_button(session, "Cancel")
      end)
      |> refute_has("#leave-group-dialog")
      |> assert_has("button", text: "Leave Group")
    end

    test "confirming leave updates the group page and My groups", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      member = generate(user(role: :user))

      generate(
        group_member(
          group_id: group.id,
          user_id: member.id,
          role: :member,
          actor: owner
        )
      )

      conn
      |> login(member)
      |> visit(~p"/groups/#{group.slug}")
      |> assert_has(".facts li", text: "Members 2")
      |> click_button("Leave Group")
      |> within("#leave-group-dialog", fn session ->
        click_button(session, "Yes, leave group")
      end)
      |> assert_has("*", text: "Successfully left the group")
      |> assert_has(".facts li", text: "Members 1")
      |> refute_has("button", text: "Leave Group")
      |> assert_has("button", text: "Join Group")
      |> visit(~p"/my-groups")
      |> refute_has("*", text: "Membership Test Group")
    end

    test "joining updates the member count without a refresh", %{
      conn: conn,
      group: group
    } do
      visitor = generate(user(role: :user))

      conn
      |> login(visitor)
      |> visit(~p"/groups/#{group.slug}")
      |> assert_has(".facts li", text: "Members 1")
      |> click_button("Join Group")
      |> assert_has("*", text: "Successfully joined the group!")
      |> assert_has(".facts li", text: "Members 2")
    end

    test "owner cannot open the leave dialog", %{conn: conn, owner: owner, group: group} do
      conn
      |> login(owner)
      |> visit(~p"/groups/#{group.slug}")
      |> refute_has("button", text: "Leave Group")
      |> refute_has("#leave-group-dialog")
    end
  end

  describe "share links" do
    test "share button opens a modal with a copy link, mailto email, and QR code", %{
      conn: conn
    } do
      owner = generate(user(role: :user))

      group =
        generate(
          group(
            owner_id: owner.id,
            is_public: true,
            name: "Share Test Group",
            actor: owner
          )
        )

      group_url = HuddlzWeb.Endpoint.url() <> ~p"/groups/#{group.slug}"

      conn
      |> visit(~p"/groups/#{group.slug}")
      |> assert_has(".share-trigger[aria-label='Share']")
      |> assert_has("#share-group-modal-url[value='#{group_url}']")
      |> assert_has("#share-group-modal a[href^='mailto:?subject=Share%20Test%20Group']")
      |> assert_has("#share-group-modal .qr-frame svg")
    end
  end
end
