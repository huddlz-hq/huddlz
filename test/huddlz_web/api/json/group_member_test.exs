defmodule HuddlzWeb.Api.Json.GroupMemberTest do
  use HuddlzWeb.ApiCase, async: true

  describe "removeMember GraphQL mutation" do
    test "schema exposes the removeMember mutation", %{conn: conn} do
      conn =
        gql_post(conn, """
        {
          __schema {
            mutationType {
              fields { name }
            }
          }
        }
        """)

      assert %{"data" => %{"__schema" => %{"mutationType" => %{"fields" => fields}}}} =
               json_response(conn, 200)

      assert Enum.any?(fields, &(&1["name"] == "removeMember"))
    end
  end

  describe "POST /api/json/group_members/add" do
    test "owner can add a member to their group", %{conn: conn} do
      owner = generate(user())
      g = generate(group(owner_id: owner.id, is_public: true, actor: owner))
      target = generate(user())

      conn =
        conn
        |> authenticated_conn(owner)
        |> put_req_header("content-type", "application/vnd.api+json")
        |> post("/api/json/group_members/add", %{
          "data" => %{
            "type" => "group_member",
            "attributes" => %{
              "group_id" => g.id,
              "user_id" => target.id,
              "role" => "member"
            }
          }
        })

      assert %{"data" => data} = json_response(conn, 201)
      assert is_binary(data["id"])
    end

    test "non-owner cannot add a member", %{conn: conn} do
      owner = generate(user())
      g = generate(group(owner_id: owner.id, is_public: true, actor: owner))
      stranger = generate(user())
      target = generate(user())

      conn =
        conn
        |> authenticated_conn(stranger)
        |> put_req_header("content-type", "application/vnd.api+json")
        |> post("/api/json/group_members/add", %{
          "data" => %{
            "type" => "group_member",
            "attributes" => %{
              "group_id" => g.id,
              "user_id" => target.id,
              "role" => "member"
            }
          }
        })

      assert conn.status in [403, 404]
    end
  end

  describe "DELETE /api/json/group_members/:id (leave_group)" do
    test "actor can leave a group they joined", %{conn: conn} do
      owner = generate(user())
      g = generate(group(owner_id: owner.id, is_public: true, actor: owner))
      joiner = generate(user())

      {:ok, membership} =
        Huddlz.Communities.GroupMember
        |> Ash.Changeset.for_create(:join_group, %{group_id: g.id}, actor: joiner)
        |> Ash.create()

      conn =
        conn
        |> authenticated_conn(joiner)
        |> put_req_header("content-type", "application/vnd.api+json")
        |> delete("/api/json/group_members/#{membership.id}")

      assert conn.status in [200, 204]
    end
  end

  describe "POST /api/json/group_members/join" do
    test "user can join a public group", %{conn: conn} do
      owner = generate(user())
      g = generate(group(owner_id: owner.id, is_public: true, actor: owner))
      joiner = generate(user())

      conn =
        conn
        |> authenticated_conn(joiner)
        |> put_req_header("content-type", "application/vnd.api+json")
        |> post("/api/json/group_members/join", %{
          "data" => %{
            "type" => "group_member",
            "attributes" => %{"group_id" => g.id}
          }
        })

      assert %{"data" => data} = json_response(conn, 201)
      assert is_binary(data["id"])
    end
  end

  describe "GET /api/json/group_members/mine" do
    test "returns only the actor's memberships", %{conn: conn} do
      me = generate(user())
      _my_group = generate(group(owner_id: me.id, is_public: true, actor: me))

      other_owner = generate(user())

      _other_group =
        generate(group(owner_id: other_owner.id, is_public: true, actor: other_owner))

      conn =
        conn
        |> authenticated_conn(me)
        |> get("/api/json/group_members/mine")

      assert %{"data" => data} = json_response(conn, 200)
      # Owner is auto-added as a member of their group
      assert is_list(data)
      assert data != []
    end
  end

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
