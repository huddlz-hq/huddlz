defmodule HuddlzWeb.Api.Json.HuddlTest do
  use HuddlzWeb.ApiCase, async: true

  describe "PATCH /api/json/huddlz/:id/rsvp" do
    test "RSVPs the actor to the huddl and bumps rsvp_count", %{conn: conn} do
      owner = generate(user())
      group = generate(group(owner_id: owner.id, is_public: true, actor: owner))

      {_group, [%{user: member}]} =
        generate_group_with_members(
          owner: owner,
          group: [name: "RSVP API Group", is_public: true, owner_id: owner.id],
          members: [%{user: generate(user()), role: :member}]
        )
        |> case do
          {g, members} -> {g, members}
        end

      _ = group
      member_user = member

      h = generate(huddl(group_id: group.id, creator_id: owner.id, actor: owner))

      conn =
        conn
        |> authenticated_conn(member_user)
        |> put_req_header("content-type", "application/vnd.api+json")
        |> patch("/api/json/huddlz/#{h.id}/rsvp", %{
          "data" => %{"type" => "huddl", "attributes" => %{}}
        })

      assert %{"data" => data} = json_response(conn, 200)
      assert data["id"] == h.id
    end
  end

  describe "GET /api/json/huddlz/upcoming" do
    test "returns future huddlz with the JSON:API envelope", %{conn: conn} do
      owner = generate(user())
      group = generate(group(owner_id: owner.id, is_public: true, actor: owner))
      h = generate(huddl(group_id: group.id, creator_id: owner.id, actor: owner))

      conn = get(conn, "/api/json/huddlz/upcoming")

      assert %{"data" => data} = json_response(conn, 200)
      ids = Enum.map(data, & &1["id"])
      assert h.id in ids
    end
  end

  describe "GET /api/json/huddlz/by_group" do
    test "returns future huddlz scoped to a group", %{conn: conn} do
      owner = generate(user())
      group = generate(group(owner_id: owner.id, is_public: true, actor: owner))
      other_group = generate(group(owner_id: owner.id, is_public: true, actor: owner))

      h = generate(huddl(group_id: group.id, creator_id: owner.id, actor: owner))
      _other = generate(huddl(group_id: other_group.id, creator_id: owner.id, actor: owner))

      conn = get(conn, "/api/json/huddlz/by_group", %{"group_id" => group.id})

      assert %{"data" => data} = json_response(conn, 200)
      ids = Enum.map(data, & &1["id"])
      assert h.id in ids
      refute Enum.any?(ids, &(&1 != h.id and &1 in [_other.id]))
    end
  end

  describe "GET /api/json/huddlz/past" do
    test "returns past huddlz", %{conn: conn} do
      owner = generate(user())
      group = generate(group(owner_id: owner.id, is_public: true, actor: owner))

      h =
        generate(
          past_huddl(
            group_id: group.id,
            creator_id: owner.id,
            starts_at: DateTime.add(DateTime.utc_now(), -2, :day),
            ends_at: DateTime.add(DateTime.utc_now(), -2, :day) |> DateTime.add(1, :hour),
            is_private: false,
            event_type: :in_person,
            physical_location: "456 Past St"
          )
        )

      conn = get(conn, "/api/json/huddlz/past")

      assert %{"data" => data} = json_response(conn, 200)
      ids = Enum.map(data, & &1["id"])
      assert h.id in ids
    end
  end
end
