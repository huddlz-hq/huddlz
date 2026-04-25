defmodule HuddlzWeb.Api.Graphql.GroupTest do
  use HuddlzWeb.ApiCase, async: true

  describe "listGroups query" do
    test "lists public groups", %{conn: conn} do
      owner = generate(user())
      g = generate(group(owner_id: owner.id, is_public: true, actor: owner))

      conn = gql_post(conn, "{ listGroups { results { id } } }")

      assert %{"data" => %{"listGroups" => %{"results" => results}}} =
               json_response(conn, 200)

      ids = Enum.map(results, & &1["id"])
      assert g.id in ids
    end
  end

  describe "getGroup query" do
    test "returns the group by slug", %{conn: conn} do
      owner = generate(user())
      g = generate(group(owner_id: owner.id, is_public: true, actor: owner))

      conn = gql_post(conn, ~s|{ getGroup(slug: "#{g.slug}") { id slug } }|)

      assert %{"data" => %{"getGroup" => %{"id" => id}}} = json_response(conn, 200)
      assert id == g.id
    end
  end
end
