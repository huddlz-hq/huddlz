defmodule HuddlzWeb.Api.Json.GroupMemberTest do
  use HuddlzWeb.ApiCase, async: true

  describe "GET /api/json/group_members/by_group?group_id=..." do
    test "returns members of the group when actor is a member", %{conn: conn} do
      owner = generate(user())
      group = generate(group(owner_id: owner.id, is_public: true, actor: owner))

      conn =
        conn
        |> authenticated_conn(owner)
        |> get("/api/json/group_members/by_group?group_id=#{group.id}")

      assert %{"data" => data} = json_response(conn, 200)
      assert is_list(data)
      assert data != []
    end

    test "returns 403/empty for non-members", %{conn: conn} do
      owner = generate(user())
      group = generate(group(owner_id: owner.id, is_public: true, actor: owner))
      stranger = generate(user())

      conn =
        conn
        |> authenticated_conn(stranger)
        |> get("/api/json/group_members/by_group?group_id=#{group.id}")

      assert conn.status in [200, 403, 404]

      if conn.status == 200 do
        assert %{"data" => []} = json_response(conn, 200)
      end
    end
  end
end
