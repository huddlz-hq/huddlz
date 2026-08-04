defmodule HuddlzWeb.HuddlLive.ShowPhotosTest do
  use HuddlzWeb.ConnCase, async: true

  import Huddlz.Generator
  import Phoenix.LiveViewTest

  alias Huddlz.Communities

  setup do
    owner = generate(user(role: :user))
    group = generate(group(owner_id: owner.id, is_public: true, actor: owner))
    %{owner: owner, group: group}
  end

  describe "photos section visibility" do
    test "creator sees the photos section on a completed huddl", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      huddl = generate(past_huddl(group_id: group.id, creator_id: owner.id))

      {:ok, view, _html} =
        conn
        |> login(owner)
        |> live(~p"/groups/#{group.slug}/huddlz/#{huddl.id}")

      assert has_element?(view, ".huddl-photos h2", "Photos")
      assert has_element?(view, ".huddl-photos-empty")
    end

    test "confirmed attendee sees the photos section on a completed huddl", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      attendee = generate(user(role: :user))
      huddl = generate(past_huddl(group_id: group.id, creator_id: owner.id))
      Communities.rsvp_huddl!(huddl, actor: attendee)

      {:ok, view, _html} =
        conn
        |> login(attendee)
        |> live(~p"/groups/#{group.slug}/huddlz/#{huddl.id}")

      assert has_element?(view, ".huddl-photos h2", "Photos")
    end

    test "a group member who never RSVPed does not see the photos section", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      outsider = generate(user(role: :user))
      huddl = generate(past_huddl(group_id: group.id, creator_id: owner.id))

      {:ok, view, _html} =
        conn
        |> login(outsider)
        |> live(~p"/groups/#{group.slug}/huddlz/#{huddl.id}")

      refute has_element?(view, ".huddl-photos")
    end

    test "the creator does not see the photos section before the huddl ends", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      huddl = generate(huddl(group_id: group.id, creator_id: owner.id, actor: owner))

      {:ok, view, _html} =
        conn
        |> login(owner)
        |> live(~p"/groups/#{group.slug}/huddlz/#{huddl.id}")

      refute has_element?(view, ".huddl-photos")
    end

    test "an anonymous visitor does not see the photos section", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      huddl = generate(past_huddl(group_id: group.id, creator_id: owner.id))

      {:ok, view, _html} = live(conn, ~p"/groups/#{group.slug}/huddlz/#{huddl.id}")

      refute has_element?(view, ".huddl-photos")
    end
  end

  describe "photos grid" do
    test "shows uploaded photos in the grid", %{conn: conn, owner: owner, group: group} do
      huddl = generate(past_huddl(group_id: group.id, creator_id: owner.id))

      {:ok, _photo} =
        Communities.create_huddl_photo(
          %{
            filename: "photo.jpg",
            content_type: "image/jpeg",
            size_bytes: 1000,
            storage_path: "/uploads/huddl_photos/#{huddl.id}/photo.jpg",
            thumbnail_path: "/uploads/huddl_photos/#{huddl.id}/photo_thumb.jpg",
            huddl_id: huddl.id
          },
          actor: owner
        )

      {:ok, view, _html} =
        conn
        |> login(owner)
        |> live(~p"/groups/#{group.slug}/huddlz/#{huddl.id}")

      refute has_element?(view, ".huddl-photos-empty")
      assert has_element?(view, ".photo-tile img")
    end
  end
end
