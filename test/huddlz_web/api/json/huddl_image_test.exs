defmodule HuddlzWeb.Api.Json.HuddlImageTest do
  use HuddlzWeb.ApiCase, async: true

  alias Huddlz.Communities.HuddlImage

  @fixture Path.expand("../../../fixtures/test_image.jpg", __DIR__)

  describe "Huddl image upload (action-level)" do
    test "owner can upload an image via the :upload action" do
      owner = generate(user())
      group = generate(group(owner_id: owner.id, is_public: true, actor: owner))
      huddl = generate(huddl(group_id: group.id, creator_id: owner.id, actor: owner))

      upload = %Plug.Upload{
        path: @fixture,
        filename: "banner.jpg",
        content_type: "image/jpeg"
      }

      assert {:ok, image} =
               HuddlImage
               |> Ash.Changeset.for_create(
                 :upload,
                 %{file: upload, huddl_id: huddl.id},
                 actor: owner
               )
               |> Ash.create()

      assert image.huddl_id == huddl.id
      assert image.filename == "banner.jpg"
      assert image.content_type == "image/jpeg"
      assert is_integer(image.size_bytes) and image.size_bytes > 0
      assert is_binary(image.storage_path)
      assert is_binary(image.thumbnail_path)
    end

    test "POST /api/json/huddl_images/upload route is registered", %{conn: conn} do
      owner = generate(user())

      conn =
        conn
        |> authenticated_conn(owner)
        |> put_req_header("content-type", "application/vnd.api+json")
        |> post("/api/json/huddl_images/upload", %{
          "data" => %{
            "type" => "huddl_image",
            "attributes" => %{"huddl_id" => Ash.UUID.generate()}
          }
        })

      # Either 422 (no file), 400, 404 (huddl), or 403 (auth) — anything BUT
      # 404 not_found_at_the_route_layer proves the route exists. 415 means
      # the Plug parser is checking content-type, which is also fine.
      refute conn.status == 404
    end

    test "non-owner cannot upload" do
      owner = generate(user())
      group = generate(group(owner_id: owner.id, is_public: true, actor: owner))
      huddl = generate(huddl(group_id: group.id, creator_id: owner.id, actor: owner))
      stranger = generate(user())

      upload = %Plug.Upload{
        path: @fixture,
        filename: "banner.jpg",
        content_type: "image/jpeg"
      }

      assert {:error, _} =
               HuddlImage
               |> Ash.Changeset.for_create(
                 :upload,
                 %{file: upload, huddl_id: huddl.id},
                 actor: stranger
               )
               |> Ash.create()
    end
  end
end
