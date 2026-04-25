defmodule HuddlzWeb.Api.Json.GroupLocationTest do
  use HuddlzWeb.ApiCase, async: true

  describe "GET /api/json/group_locations/by_group" do
    test "lists locations for the given group", %{conn: conn} do
      owner = generate(user())
      g = generate(group(owner_id: owner.id, is_public: true, actor: owner))

      {:ok, location} =
        Huddlz.Communities.GroupLocation
        |> Ash.Changeset.for_create(
          :create,
          %{
            name: "Community Center",
            address: "123 Test Ave",
            latitude: 30.27,
            longitude: -97.74,
            group_id: g.id
          },
          actor: owner
        )
        |> Ash.create()

      conn = get(conn, "/api/json/group_locations/by_group?group_id=#{g.id}")

      assert %{"data" => data} = json_response(conn, 200)
      ids = Enum.map(data, & &1["id"])
      assert location.id in ids
    end
  end
end
