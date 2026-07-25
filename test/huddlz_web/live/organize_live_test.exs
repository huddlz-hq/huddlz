defmodule HuddlzWeb.OrganizeLiveTest do
  use HuddlzWeb.ConnCase, async: true

  test "organizer picker uses the shared group cover fallback", %{conn: conn} do
    owner = generate(user(role: :user))
    group = generate(group(name: "Organizer Crew", owner_id: owner.id, actor: owner))

    conn
    |> login(owner)
    |> visit(~p"/organize")
    |> assert_has(".organizer-group-row[href='/organize/#{group.slug}']")
    |> assert_has("#organizer-group-cover-#{group.id}[data-testid='group-cover']")
    |> assert_has("#organizer-group-cover-#{group.id} .group-cover-signal", text: "OC")
  end
end
