defmodule HuddlzWeb.OrganizeLiveHuddlzTest do
  use HuddlzWeb.ConnCase, async: true

  alias Huddlz.Communities
  alias Huddlz.Communities.Huddl

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

  test "shows the huddl's local time instead of raw UTC in the list meta", %{
    conn: conn,
    group: group,
    owner: owner
  } do
    # 17:00 UTC on this date is 1:00 PM in America/New_York (EDT).
    tz_huddl =
      Ash.Seed.seed!(Huddl, %{
        title: "Timezone Aware Huddl",
        description: "Check the local time",
        starts_at: ~U[2030-05-04 17:00:00Z],
        ends_at: ~U[2030-05-04 19:00:00Z],
        event_type: :virtual,
        virtual_link: "https://example.com/tz",
        is_private: false,
        group_id: group.id,
        creator_id: owner.id,
        lifecycle_state: :published,
        published_at: DateTime.utc_now(),
        published_by_id: owner.id,
        time_zone: "America/New_York"
      })

    conn
    |> login(owner)
    |> visit(~p"/organize/#{group.slug}/huddlz")
    |> assert_has("#organize-huddl-link-#{tz_huddl.id}", text: "Timezone Aware Huddl")
    |> assert_has(".meta", text: "01:00 PM")
    |> refute_has(".meta", text: "05:00 PM")
  end
end
