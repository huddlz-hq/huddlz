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
