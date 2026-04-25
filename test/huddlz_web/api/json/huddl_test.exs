defmodule HuddlzWeb.Api.Json.HuddlTest do
  use HuddlzWeb.ApiCase, async: true

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
end
