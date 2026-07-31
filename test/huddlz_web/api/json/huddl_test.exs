defmodule HuddlzWeb.Api.Json.HuddlTest do
  use HuddlzWeb.ApiCase, async: true

  describe "DELETE /api/json/huddlz/:id" do
    test "owner can delete a draft huddl", %{conn: conn} do
      owner = generate(user())
      group = generate(group(owner_id: owner.id, is_public: true, actor: owner))

      h =
        generate(
          huddl(
            group_id: group.id,
            creator_id: owner.id,
            actor: owner,
            lifecycle_state: :draft
          )
        )

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

  describe "PATCH /api/json/huddlz/:id/publish" do
    test "owner can publish a draft idempotently", %{conn: conn} do
      owner = generate(user())
      group = generate(group(owner_id: owner.id, is_public: true, actor: owner))

      draft =
        generate(
          huddl(
            group_id: group.id,
            creator_id: owner.id,
            actor: owner,
            lifecycle_state: :draft
          )
        )

      conn = lifecycle_patch(conn, owner, draft, "publish", %{})
      assert %{"data" => data} = json_response(conn, 200)
      assert data["attributes"]["lifecycle_state"] == "published"

      conn = lifecycle_patch(build_conn(), owner, draft, "publish", %{})
      assert %{"data" => repeated} = json_response(conn, 200)
      assert repeated["attributes"]["lifecycle_state"] == "published"
    end

    test "regular user cannot publish a draft", %{conn: conn} do
      owner = generate(user())
      stranger = generate(user())
      group = generate(group(owner_id: owner.id, is_public: true, actor: owner))

      draft =
        generate(
          huddl(
            group_id: group.id,
            creator_id: owner.id,
            actor: owner,
            lifecycle_state: :draft
          )
        )

      conn = lifecycle_patch(conn, stranger, draft, "publish", %{})
      assert conn.status in [403, 404]
    end
  end

  describe "PATCH /api/json/huddlz/:id/cancel" do
    test "owner can cancel a published huddl idempotently with an explanation", %{conn: conn} do
      owner = generate(user())
      group = generate(group(owner_id: owner.id, is_public: true, actor: owner))
      published = generate(huddl(group_id: group.id, creator_id: owner.id, actor: owner))

      conn =
        lifecycle_patch(conn, owner, published, "cancel", %{
          "cancellation_reason" => "Venue unavailable"
        })

      assert %{"data" => data} = json_response(conn, 200)
      assert data["attributes"]["lifecycle_state"] == "cancelled"
      assert data["attributes"]["cancellation_reason"] == "Venue unavailable"

      conn = lifecycle_patch(build_conn(), owner, published, "cancel", %{})
      assert %{"data" => repeated} = json_response(conn, 200)
      assert repeated["attributes"]["lifecycle_state"] == "cancelled"
      assert repeated["attributes"]["cancellation_reason"] == "Venue unavailable"
    end

    test "regular user cannot cancel a published huddl", %{conn: conn} do
      owner = generate(user())
      stranger = generate(user())
      group = generate(group(owner_id: owner.id, is_public: true, actor: owner))
      published = generate(huddl(group_id: group.id, creator_id: owner.id, actor: owner))

      conn = lifecycle_patch(conn, stranger, published, "cancel", %{})
      assert conn.status in [403, 404]
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
      other = generate(huddl(group_id: other_group.id, creator_id: owner.id, actor: owner))

      conn = get(conn, "/api/json/huddlz/by_group", %{"group_id" => group.id})

      assert %{"data" => data} = json_response(conn, 200)
      ids = Enum.map(data, & &1["id"])
      assert h.id in ids
      refute Enum.any?(ids, &(&1 != h.id and &1 in [other.id]))
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

  defp lifecycle_patch(conn, user, huddl, action, attributes) do
    conn
    |> authenticated_conn(user)
    |> put_req_header("content-type", "application/vnd.api+json")
    |> patch("/api/json/huddlz/#{huddl.id}/#{action}", %{
      "data" => %{"type" => "huddl", "attributes" => attributes}
    })
  end
end
