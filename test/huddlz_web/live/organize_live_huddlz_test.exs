defmodule HuddlzWeb.OrganizeLiveHuddlzTest do
  use HuddlzWeb.ConnCase, async: true

  alias Huddlz.Communities

  setup do
    owner = generate(user(role: :user))
    group = generate(group(is_public: true, owner_id: owner.id, actor: owner))

    %{group: group, owner: owner}
  end

  test "current filter follows organizer view changes", %{conn: conn, group: group, owner: owner} do
    session =
      conn
      |> login(owner)
      |> visit(~p"/organize/#{group.slug}/huddlz")
      |> assert_has("#organize-huddlz-filters .is-active[aria-current='page']", text: "Upcoming")
      |> refute_has("#organize-huddlz-filters .chip:not(.is-active)[aria-current]")

    Enum.reduce(["Drafts", "Cancelled", "Past", "Upcoming"], session, fn label, session ->
      session
      |> click_link("#organize-huddlz-filters a", label)
      |> assert_has("#organize-huddlz-filters .is-active[aria-current='page']", text: label)
      |> refute_has("#organize-huddlz-filters .chip:not(.is-active)[aria-current]")
    end)
  end

  test "a long list pages twenty at a time", %{conn: conn, group: group, owner: owner} do
    today = Huddlz.Generator.eastern_today()

    source =
      generate(
        huddl(
          title: "Long Running",
          group_id: group.id,
          creator_id: owner.id,
          actor: owner,
          date: Date.add(today, 1),
          is_recurring: true,
          frequency: "weekly",
          # 25 weekly dates; the cutoff sits the day after the last one.
          repeat_until: Date.add(today, 1 + 7 * 24 + 1)
        )
      )

    Oban.drain_queue(queue: :default)

    conn
    |> login(owner)
    |> visit(~p"/organize/#{group.slug}/huddlz")
    |> assert_has("#organize-huddlz-filters .chip .chip-count", text: "25")
    |> assert_has("#organize-huddlz-list .org-huddl", count: 20)
    |> assert_has("#organize-huddl-#{source.id} .org-huddl-series", text: "Weekly")
    |> assert_has(".org-list-more button", text: "Show 5 more")
    |> assert_has(".org-list-more", text: "5 more huddlz after these")
    |> click_button(".org-list-more button", "Show 5 more")
    |> assert_has("#organize-huddlz-list .org-huddl", count: 25)
    |> refute_has(".org-list-more")
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
