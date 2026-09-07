defmodule HuddlzWeb.Api.Json.HuddlArtworkTest do
  use HuddlzWeb.ApiCase, async: true

  test "artwork uses the current huddl image, then group fallback, then null", %{conn: conn} do
    owner = generate(user())
    group = generate(group(owner_id: owner.id, is_public: true, actor: owner))
    huddl = generate(huddl(group_id: group.id, actor: owner, thumbnail_url: nil))
    group_image = create_image(Huddlz.Communities.GroupImage, :group_id, group.id, owner)

    assert_artwork(conn, huddl, group_image.thumbnail_path)

    huddl_image = create_image(Huddlz.Communities.HuddlCoverImage, :huddl_id, huddl.id, owner)
    assert_artwork(conn, huddl, huddl_image.thumbnail_path)

    huddl_image |> Ash.Changeset.for_update(:soft_delete, %{}, actor: owner) |> Ash.update!()
    assert_artwork(conn, huddl, group_image.thumbnail_path)

    group_image |> Ash.Changeset.for_update(:soft_delete, %{}, actor: owner) |> Ash.update!()
    assert_artwork(conn, huddl, nil)
  end

  test "field selection includes artwork only when requested", %{conn: conn} do
    owner = generate(user())
    group = generate(group(owner_id: owner.id, is_public: true, actor: owner))
    huddl = generate(huddl(group_id: group.id, actor: owner, thumbnail_url: nil))
    image = create_image(Huddlz.Communities.GroupImage, :group_id, group.id, owner)

    for path <- ["/api/json/huddlz", "/api/json/huddlz/#{huddl.id}"] do
      params = %{"date_filter" => "upcoming", "fields" => %{"huddl" => "title,image_url"}}
      body = conn |> get(path, params) |> json_response(200)
      assert [data] = List.wrap(body["data"])

      assert data["attributes"] == %{
               "title" => huddl.title,
               "image_url" => HuddlzWeb.Endpoint.url() <> image.thumbnail_path
             }

      body = conn |> get(path, put_in(params, ["fields", "huddl"], "title")) |> json_response(200)
      assert [data] = List.wrap(body["data"])
      assert data["attributes"] == %{"title" => huddl.title}

      for field <- ["display_image_url", "current_image_url"] do
        body =
          conn |> get(path, put_in(params, ["fields", "huddl"], field)) |> json_response(400)

        assert Enum.any?(body["errors"], &(&1["code"] == "invalid_field"))
      end
    end
  end

  test "anonymous and unrelated clients cannot discover unauthorized artwork", %{conn: conn} do
    owner = generate(user())
    stranger = generate(user())
    public_group = generate(group(owner_id: owner.id, is_public: true, actor: owner))
    private_group = generate(group(owner_id: owner.id, is_public: false, actor: owner))

    for opts <- [
          [group_id: public_group.id, is_private: true],
          [group_id: private_group.id],
          [group_id: public_group.id, lifecycle_state: :draft],
          [group_id: public_group.id, lifecycle_state: :cancelled]
        ] do
      huddl =
        generate(
          huddl(Keyword.delete(opts, :lifecycle_state) ++ [actor: owner, thumbnail_url: nil])
        )

      huddl = Ash.Seed.update!(huddl, %{lifecycle_state: opts[:lifecycle_state] || :published})

      Ash.Seed.seed!(Huddlz.Communities.HuddlCoverImage, %{
        huddl_id: huddl.id,
        filename: "private.jpg",
        content_type: "image/jpeg",
        size_bytes: 100,
        storage_path: "/uploads/430/#{huddl.id}.jpg",
        thumbnail_path: "/uploads/430/#{huddl.id}_thumb.jpg"
      })

      for client <- [conn, authenticated_conn(conn, stranger)] do
        body =
          client
          |> get("/api/json/huddlz", %{
            "date_filter" => "upcoming",
            "fields" => %{"huddl" => "title,image_url"}
          })
          |> json_response(200)

        assert body["data"] == []

        client
        |> get("/api/json/huddlz/#{huddl.id}", %{"fields" => %{"huddl" => "image_url"}})
        |> json_response(404)
      end
    end
  end

  test "OpenAPI documents the public artwork URL", %{conn: conn} do
    schema = conn |> get("/api/json/open_api") |> response(200) |> Jason.decode!()

    properties =
      get_in(schema, ["components", "schemas", "huddl", "properties", "attributes", "properties"])

    assert %{"type" => "string", "nullable" => true} in properties["image_url"]["anyOf"]
    assert %{"type" => "null"} in properties["image_url"]["anyOf"]
    refute Map.has_key?(properties, "display_image_url")
    refute Map.has_key?(properties, "current_image_url")
  end

  defp assert_artwork(conn, huddl, path) do
    expected = if path, do: HuddlzWeb.Endpoint.url() <> path

    for route <- ["/api/json/huddlz?date_filter=upcoming", "/api/json/huddlz/#{huddl.id}"] do
      body = conn |> get(route) |> json_response(200)
      assert [data] = List.wrap(body["data"])
      assert data["id"] == huddl.id
      assert Map.fetch!(data["attributes"], "image_url") == expected
    end
  end

  defp create_image(resource, parent_key, parent_id, owner) do
    path = "/uploads/430/#{Ash.UUID.generate()}.jpg"

    resource
    |> Ash.Changeset.for_create(
      :create,
      %{
        parent_key => parent_id,
        :filename => "cover.jpg",
        :content_type => "image/jpeg",
        :size_bytes => 100,
        :storage_path => path,
        :thumbnail_path => path <> "_thumb.jpg"
      },
      actor: owner
    )
    |> Ash.create!()
  end
end
