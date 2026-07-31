defmodule HuddlzWeb.OrganizeLiveHuddlzTest do
  use HuddlzWeb.ConnCase, async: true

  alias Huddlz.Communities

  setup do
    owner = generate(user(role: :user))
    group = generate(group(is_public: true, owner_id: owner.id, actor: owner))

    %{group: group, owner: owner}
  end

  test "cancelled huddlz link directly to their detail page", %{
    conn: conn,
    group: group,
    owner: owner
  } do
    huddl =
      generate(
        huddl(
          title: "Cancelled Workshop",
          group_id: group.id,
          creator_id: owner.id,
          actor: owner
        )
      )

    cancelled_huddl = Communities.cancel_huddl!(huddl, "Venue unavailable", actor: owner)

    conn
    |> login(owner)
    |> visit(~p"/organize/#{group.slug}/huddlz?filter=cancelled")
    |> assert_has(
      "#organize-huddl-link-#{cancelled_huddl.id}[href='/groups/#{group.slug}/huddlz/#{cancelled_huddl.id}']",
      text: "Cancelled Workshop"
    )
    |> refute_has(
      "#organize-huddl-link-#{cancelled_huddl.id}[href='/groups/#{group.slug}/huddlz/#{cancelled_huddl.id}/edit']"
    )
  end
end
