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

      private_huddl =
        generate(
          huddl(
            group_id: group.id,
            creator_id: owner.id,
            actor: owner,
            is_private: true,
            title: "Members Only Planning"
          )
        )

      private_past_huddl =
        generate(
          past_huddl(
            group_id: group.id,
            creator_id: owner.id,
            is_private: true,
            title: "Members Only Retrospective"
          )
        )

      session =
        conn
        |> login(member)
        |> visit(~p"/groups/#{group.slug}")
        |> assert_has(".facts li", text: "Members 2")
        |> assert_has("h3", text: private_huddl.title)
        |> click_button("Past")
        |> assert_has("h3", text: private_past_huddl.title)
        |> click_button("Upcoming")

      session
      |> click_button("Leave Group")
      |> within("#leave-group-dialog", fn session ->
        click_button(session, "Yes, leave group")
      end)
      |> assert_has("*", text: "Successfully left the group")
      |> assert_has(".facts li", text: "Members 1")
      |> refute_has("button", text: "Leave Group")
      |> assert_has("button", text: "Join Group")
      |> refute_has("h3", text: private_huddl.title)
      |> click_button("Past")
      |> refute_has("h3", text: private_past_huddl.title)
      |> visit(~p"/my-groups")
      |> refute_has("*", text: "Membership Test Group")
    end

    test "joining refreshes the member count and reveals members-only huddlz", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      visitor = generate(user(role: :user))

      private_huddl =
        generate(
          huddl(
            group_id: group.id,
            creator_id: owner.id,
            actor: owner,
            is_private: true,
            title: "Private Member Welcome"
          )
        )

      conn
      |> login(visitor)
      |> visit(~p"/groups/#{group.slug}")
      |> assert_has(".facts li", text: "Members 1")
      |> refute_has("h3", text: private_huddl.title)
      |> click_button("Join Group")
      |> assert_has("*", text: "Successfully joined the group!")
      |> assert_has(".facts li", text: "Members 2")
      |> assert_has("h3", text: private_huddl.title)
    end

    test "external role loss and removal refresh an already-mounted page", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      organizer = generate(user(role: :user))

      membership =
        generate(
          group_member(
            group_id: group.id,
            user_id: organizer.id,
            role: :organizer,
            actor: owner
          )
        )

      private_huddl =
        generate(
          huddl(
            group_id: group.id,
            creator_id: owner.id,
            actor: owner,
            is_private: true,
            title: "Organizer Planning Huddl"
          )
        )

      session =
        conn
        |> login(organizer)
        |> visit(~p"/groups/#{group.slug}")
        |> assert_has("a", text: "Create Huddl")
        |> assert_has("h3", text: private_huddl.title)

      membership =
        membership
        |> Ash.Changeset.for_update(:change_role, %{role: :member}, actor: owner)
        |> Ash.update!()

      session =
        session
        |> refute_has("a", text: "Create Huddl", timeout: 1_000)
        |> click_button("Leave Group")
        |> assert_has("#leave-group-dialog")

      membership
      |> Ash.Changeset.for_destroy(
        :remove_member,
        %{group_id: group.id, user_id: organizer.id},
        actor: owner
      )
      |> Ash.destroy!()

      session
      |> refute_has("#leave-group-dialog", timeout: 1_000)
      |> assert_has(".facts li", text: "Members 1")
      |> refute_has("h3", text: private_huddl.title)
      |> assert_has("button", text: "Join Group")
      |> unwrap(fn view ->
        Phoenix.LiveViewTest.render_hook(view, "switch_tab", %{"tab" => "past"})
      end)
      |> refute_has("h3", text: private_huddl.title)
    end

    test "owner cannot open the leave dialog", %{conn: conn, owner: owner, group: group} do
      conn
      |> login(owner)
      |> visit(~p"/groups/#{group.slug}")
      |> refute_has("button", text: "Leave Group")
      |> refute_has("#leave-group-dialog")
    end
  end
end
