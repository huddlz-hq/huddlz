defmodule HuddlzWeb.Api.Graphql.HuddlTest do
  use HuddlzWeb.ApiCase, async: true

  describe "upcomingHuddlz query" do
    test "returns future huddlz", %{conn: conn} do
      owner = generate(user())
      group = generate(group(owner_id: owner.id, is_public: true, actor: owner))
      h = generate(huddl(group_id: group.id, creator_id: owner.id, actor: owner))

      conn = gql_post(conn, "{ upcomingHuddlz { id } }")

      assert %{"data" => %{"upcomingHuddlz" => results}} = json_response(conn, 200)
      ids = Enum.map(results, & &1["id"])
      assert h.id in ids
    end
  end
end
