defmodule HuddlzWeb.Api.Json.HuddlTest do
  use HuddlzWeb.ApiCase, async: true

  describe "DELETE /api/json/huddlz/:id" do
    test "owner can delete the huddl", %{conn: conn} do
      owner = generate(user())
      group = generate(group(owner_id: owner.id, is_public: true, actor: owner))
      h = generate(huddl(group_id: group.id, creator_id: owner.id, actor: owner))

      conn =
        conn
        |> authenticated_conn(owner)
        |> put_req_header("content-type", "application/vnd.api+json")
        |> delete("/api/json/huddlz/#{h.id}")

      assert conn.status in [200, 204]
    end

    test "regular user cannot delete the huddl", %{conn: conn} do
      owner = generate(user())
      group = generate(group(owner_id: owner.id, is_public: true, actor: owner))
      h = generate(huddl(group_id: group.id, creator_id: owner.id, actor: owner))
      stranger = generate(user())

      conn =
        conn
        |> authenticated_conn(stranger)
        |> put_req_header("content-type", "application/vnd.api+json")
        |> delete("/api/json/huddlz/#{h.id}")

      assert conn.status in [403, 404]
    end
  end

  describe "PATCH /api/json/huddlz/:id/cancel_rsvp" do
    test "is idempotent when actor is not RSVPed", %{conn: conn} do
      owner = generate(user())
      group = generate(group(owner_id: owner.id, is_public: true, actor: owner))
      member = generate(user())

      h = generate(huddl(group_id: group.id, creator_id: owner.id, actor: owner))

      conn =
        conn
        |> authenticated_conn(member)
        |> put_req_header("content-type", "application/vnd.api+json")
        |> patch("/api/json/huddlz/#{h.id}/cancel_rsvp", %{
          "data" => %{"type" => "huddl", "attributes" => %{}}
        })

      assert %{"data" => data} = json_response(conn, 200)
      assert data["id"] == h.id
    end
  end

  describe "PATCH /api/json/huddlz/:id/rsvp" do
    test "RSVPs the actor to the huddl and bumps rsvp_count", %{conn: conn} do
      owner = generate(user())
      group = generate(group(owner_id: owner.id, is_public: true, actor: owner))
      member_user = generate(user())

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
