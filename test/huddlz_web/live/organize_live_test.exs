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
    |> refute_has("#organizer-group-cover-#{group.id} img")
  end

  test "organizer picker displays the group's current cover", %{conn: conn} do
    owner = generate(user(role: :user))
    group = generate(group(owner_id: owner.id, actor: owner))
    path = "/uploads/group_images/#{group.id}/cover.png"

    Huddlz.Communities.create_group_image!(
      %{
        filename: "cover.png",
        content_type: "image/png",
        size_bytes: 1000,
        storage_path: path,
        thumbnail_path: path,
        group_id: group.id
      },
      actor: owner
    )

    conn
    |> login(owner)
    |> visit(~p"/organize")
    |> assert_has("#organizer-group-cover-#{group.id} img[src='#{path}']")
  end
end
