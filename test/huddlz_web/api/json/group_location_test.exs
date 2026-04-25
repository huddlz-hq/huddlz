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

  describe "POST /api/json/group_locations" do
    test "owner can create a location", %{conn: conn} do
      owner = generate(user())
      g = generate(group(owner_id: owner.id, is_public: true, actor: owner))

      conn =
        conn
        |> authenticated_conn(owner)
        |> put_req_header("content-type", "application/vnd.api+json")
        |> post("/api/json/group_locations", %{
          "data" => %{
            "type" => "group_location",
            "attributes" => %{
              "name" => "Test Venue",
              "address" => "456 API Ave",
              "latitude" => 32.78,
              "longitude" => -96.80,
              "group_id" => g.id
            }
          }
        })

      assert %{"data" => data} = json_response(conn, 201)
      assert is_binary(data["id"])
    end
  end

  describe "PATCH /api/json/group_locations/:id" do
    test "owner can update name", %{conn: conn} do
      owner = generate(user())
      g = generate(group(owner_id: owner.id, is_public: true, actor: owner))

      {:ok, loc} =
        Huddlz.Communities.GroupLocation
        |> Ash.Changeset.for_create(
          :create,
          %{
            name: "Original",
            address: "1 Place",
            latitude: 1.0,
            longitude: 1.0,
            group_id: g.id
          },
          actor: owner
        )
        |> Ash.create()

      conn =
        conn
        |> authenticated_conn(owner)
        |> put_req_header("content-type", "application/vnd.api+json")
        |> patch("/api/json/group_locations/#{loc.id}", %{
          "data" => %{
            "type" => "group_location",
            "attributes" => %{"name" => "Renamed"}
          }
        })

      assert %{"data" => _} = json_response(conn, 200)
    end
  end

  describe "DELETE /api/json/group_locations/:id" do
    test "owner can destroy a location", %{conn: conn} do
      owner = generate(user())
      g = generate(group(owner_id: owner.id, is_public: true, actor: owner))

      {:ok, loc} =
        Huddlz.Communities.GroupLocation
        |> Ash.Changeset.for_create(
          :create,
          %{
            name: "Doomed",
            address: "1 Place",
            latitude: 1.0,
            longitude: 1.0,
            group_id: g.id
          },
          actor: owner
        )
        |> Ash.create()

      conn =
        conn
        |> authenticated_conn(owner)
        |> put_req_header("content-type", "application/vnd.api+json")
        |> delete("/api/json/group_locations/#{loc.id}")

      assert conn.status in [200, 204]
    end
  end
end
