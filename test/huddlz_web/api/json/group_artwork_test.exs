defmodule HuddlzWeb.Api.Json.GroupArtworkTest do
  use HuddlzWeb.ApiCase, async: true

  test "group image_url returns the current group image and null when absent or removed", %{
    conn: conn
  } do
    owner = generate(user())
    group = generate(group(owner_id: owner.id, is_public: true, actor: owner))

    assert_group_image(conn, owner, group, nil)

    image = create_group_image(group.id, owner)
    assert_group_image(conn, owner, group, image.thumbnail_path)

    image |> Ash.Changeset.for_update(:soft_delete, %{}, actor: owner) |> Ash.update!()
    assert_group_image(conn, owner, group, nil)
  end

  test "field selection includes image_url only when requested and hides internal current_image_url",
       %{conn: conn} do
    owner = generate(user())
    group = generate(group(owner_id: owner.id, is_public: true, actor: owner))
    image = create_group_image(group.id, owner)

    for path <- ["/api/json/groups", "/api/json/groups/#{group.id}"] do
      body =
        conn
        |> get(path, %{"fields" => %{"group" => "name,image_url"}})
        |> json_response(200)

      record = find_group(body["data"], group.id)

      assert record["attributes"] == %{
               "name" => to_string(group.name),
               "image_url" => HuddlzWeb.Endpoint.url() <> image.thumbnail_path
             }

      body =
        conn
        |> get(path, %{"fields" => %{"group" => "name"}})
        |> json_response(200)

      record = find_group(body["data"], group.id)
      assert record["attributes"] == %{"name" => to_string(group.name)}

      body =
        conn
        |> get(path, %{"fields" => %{"group" => "current_image_url"}})
        |> json_response(400)

      assert Enum.any?(body["errors"], &(&1["code"] == "invalid_field"))
    end
  end

  test "anonymous and unrelated clients cannot discover a private group's image", %{conn: conn} do
    owner = generate(user())
    stranger = generate(user())
    private_group = generate(group(owner_id: owner.id, is_public: false, actor: owner))
    image = create_group_image(private_group.id, owner)

    for client <- [conn, authenticated_conn(conn, stranger)] do
      client
      |> get("/api/json/groups/#{private_group.id}", %{"fields" => %{"group" => "image_url"}})
      |> json_response(404)
    end

    owner_body =
      conn
      |> authenticated_conn(owner)
      |> get("/api/json/groups/#{private_group.id}")
      |> json_response(200)

    assert owner_body["data"]["attributes"]["image_url"] ==
             HuddlzWeb.Endpoint.url() <> image.thumbnail_path
  end

  test "OpenAPI documents group image_url and omits internal current_image_url", %{conn: conn} do
    schema = conn |> get("/api/json/open_api") |> response(200) |> Jason.decode!()

    properties =
      get_in(schema, ["components", "schemas", "group", "properties", "attributes", "properties"])

    image_schema = Map.fetch!(properties, "image_url")

    assert (image_schema["type"] == "string" and image_schema["nullable"] == true) or
             %{"type" => "string", "nullable" => true} in List.wrap(image_schema["anyOf"])

    refute Map.has_key?(properties, "current_image_url")
  end

  defp assert_group_image(conn, owner, group, path) do
    expected = if path, do: HuddlzWeb.Endpoint.url() <> path

    for {client, route} <- [
          {conn, "/api/json/groups"},
          {conn, "/api/json/groups/#{group.id}"},
          {authenticated_conn(conn, owner), "/api/json/groups/mine"}
        ] do
      body = client |> get(route) |> json_response(200)
      record = find_group(body["data"], group.id)
      assert record, "expected group #{group.id} in #{route}"
      assert Map.fetch!(record["attributes"], "image_url") == expected
    end
  end

  defp find_group(data, id) when is_list(data), do: Enum.find(data, &(&1["id"] == id))
  defp find_group(%{"id" => id} = data, id), do: data
  defp find_group(_, _), do: nil

  defp create_group_image(group_id, owner) do
    path = "/uploads/groups/#{Ash.UUID.generate()}.jpg"

    Huddlz.Communities.GroupImage
    |> Ash.Changeset.for_create(
      :create,
      %{
        group_id: group_id,
        filename: "group.jpg",
        content_type: "image/jpeg",
        size_bytes: 100,
        storage_path: path,
        thumbnail_path: path <> "_thumb.jpg"
      },
      actor: owner
    )
    |> Ash.create!()
  end
end
