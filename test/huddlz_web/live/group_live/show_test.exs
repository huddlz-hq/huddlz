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

    test "leave button shows a pending state while submitting", %{
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
      |> assert_has("button[phx-disable-with='Leaving...']", text: "Leave Group")
    end
  end
end
