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

    test "owner can upload via multipart HTTP end-to-end", %{conn: conn} do
      owner = generate(user())
      group = generate(group(owner_id: owner.id, is_public: true, actor: owner))
      huddl = generate(huddl(group_id: group.id, creator_id: owner.id, actor: owner))

      conn =
        conn
        |> authenticated_conn(owner)
        |> multipart_post(
          "/api/json/huddl_images/upload",
          %{"huddl_id" => huddl.id, "file" => "the_file"},
          type: "huddl_image",
          file: %{
            part_name: "the_file",
            path: @fixture,
            filename: "banner.jpg",
            content_type: "image/jpeg"
          }
        )

      assert %{"data" => data} = json_response(conn, 201)
      attrs = data["attributes"] || %{}
      assert is_binary(attrs["storage_path"])
      assert is_binary(attrs["thumbnail_path"])
      assert attrs["filename"] == "banner.jpg"
      assert Huddlz.Storage.exists?(attrs["storage_path"])
    end

    test "rejects an .exe upload with a friendly message" do
      owner = generate(user())
      group = generate(group(owner_id: owner.id, is_public: true, actor: owner))
      huddl = generate(huddl(group_id: group.id, creator_id: owner.id, actor: owner))

      bad_file = Path.join(System.tmp_dir!(), "evil-#{:rand.uniform(99_999)}.exe")
      File.write!(bad_file, "MZ\x90\x00")

      try do
        upload = %Plug.Upload{
          path: bad_file,
          filename: "evil.exe",
          content_type: "application/octet-stream"
        }

        assert {:error, %Ash.Error.Invalid{errors: errors}} =
                 HuddlImage
                 |> Ash.Changeset.for_create(
                   :upload,
                   %{file: upload, huddl_id: huddl.id},
                   actor: owner
                 )
                 |> Ash.create()

        # The user-facing message must NOT be the raw atom inspect form.
        messages = Enum.map(errors, &Exception.message/1)
        assert Enum.any?(messages, &(&1 =~ "Invalid file type"))
        refute Enum.any?(messages, &(&1 =~ ":invalid_extension"))
      after
        File.rm(bad_file)
      end
    end

    test "missing huddl_id is rejected with a friendly changeset error" do
      owner = generate(user())

      upload = %Plug.Upload{
        path: @fixture,
        filename: "banner.jpg",
        content_type: "image/jpeg"
      }

      # Bypass policies so the failure is unambiguously the missing parent_id,
      # not the huddl-ownership check that would otherwise deny first.
      assert {:error, %Ash.Error.Invalid{errors: errors}} =
               HuddlImage
               |> Ash.Changeset.for_create(:upload, %{file: upload}, actor: owner)
               |> Ash.create(authorize?: false)

      assert Enum.any?(errors, fn err ->
               match?(%Ash.Error.Changes.InvalidAttribute{field: :huddl_id}, err) and
                 Exception.message(err) =~ "is required"
             end)
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
