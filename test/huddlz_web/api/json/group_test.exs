defmodule HuddlzWeb.Api.Json.GroupTest do
  use HuddlzWeb.ApiCase, async: true

  describe "GET /api/json/groups" do
    test "lists public groups", %{conn: conn} do
      owner = generate(user())
      g = generate(group(owner_id: owner.id, is_public: true, actor: owner))

      conn = get(conn, "/api/json/groups")

      assert %{"data" => data} = json_response(conn, 200)
      ids = Enum.map(data, & &1["id"])
      assert g.id in ids
    end
  end

  describe "PATCH /api/json/groups/:id" do
    test "owner can update group details", %{conn: conn} do
      owner = generate(user())
      g = generate(group(owner_id: owner.id, is_public: true, actor: owner))

      conn =
        conn
        |> authenticated_conn(owner)
        |> put_req_header("content-type", "application/vnd.api+json")
        |> patch("/api/json/groups/#{g.id}", %{
          "data" => %{
            "type" => "group",
            "attributes" => %{"description" => "Updated description"}
          }
        })

      assert %{"data" => data} = json_response(conn, 200)
      assert data["id"] == g.id

      reloaded = Ash.get!(Huddlz.Communities.Group, g.id, authorize?: false)
      assert reloaded.description |> to_string() == "Updated description"
    end

    test "non-owner cannot update group details", %{conn: conn} do
      owner = generate(user())
      g = generate(group(owner_id: owner.id, is_public: true, actor: owner))
      stranger = generate(user())

      conn =
        conn
        |> authenticated_conn(stranger)
        |> put_req_header("content-type", "application/vnd.api+json")
        |> patch("/api/json/groups/#{g.id}", %{
          "data" => %{
            "type" => "group",
            "attributes" => %{"description" => "I shouldn't be able to do this"}
          }
        })

      assert conn.status in [403, 404]
    end
  end

  describe "POST /api/json/groups" do
    test "authenticated user can create a group", %{conn: conn} do
      me = generate(user())

      conn =
        conn
        |> authenticated_conn(me)
        |> put_req_header("content-type", "application/vnd.api+json")
        |> post("/api/json/groups", %{
          "data" => %{
            "type" => "group",
            "attributes" => %{
              "name" => "API Created Group",
              "description" => "Created via JSON:API",
              "location" => "Tucson",
              "is_public" => true,
              "owner_id" => me.id,
              "slug" => "api-created-group"
            }
          }
        })

      assert %{"data" => data} = json_response(conn, 201)
      assert is_binary(data["id"])
    end
  end

  describe "GET /api/json/groups/mine" do
    test "returns only groups owned by the actor", %{conn: conn} do
      me = generate(user())
      mine = generate(group(owner_id: me.id, is_public: true, actor: me))

      other_owner = generate(user())

      _other_group =
        generate(group(owner_id: other_owner.id, is_public: true, actor: other_owner))

      conn =
        conn
        |> authenticated_conn(me)
        |> get("/api/json/groups/mine")

      assert %{"data" => data} = json_response(conn, 200)
      ids = Enum.map(data, & &1["id"])
      assert mine.id in ids
      assert length(ids) == 1
    end
  end

  describe "GET /api/json/groups/search" do
    test "matches groups by name via trigram search", %{conn: conn} do
      owner = generate(user())

      target =
        generate(
          group(
            owner_id: owner.id,
            is_public: true,
            actor: owner,
            name: "Phoenix Engineers"
          )
        )

      conn = get(conn, "/api/json/groups/search?query=Phoenix")

      assert %{"data" => data} = json_response(conn, 200)
      ids = Enum.map(data, & &1["id"])
      assert target.id in ids
    end
  end

  describe "GET /api/json/groups/by_slug/:slug" do
    test "returns the group by slug", %{conn: conn} do
      owner = generate(user())
      g = generate(group(owner_id: owner.id, is_public: true, actor: owner))

      conn = get(conn, "/api/json/groups/by_slug/#{g.slug}")

      assert %{"data" => %{"id" => id}} = json_response(conn, 200)
      assert id == g.id
    end
  end
end
