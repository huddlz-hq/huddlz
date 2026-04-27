defmodule HuddlzWeb.Api.Json.ProfilePictureTest do
  use HuddlzWeb.ApiCase, async: true

  alias Huddlz.Accounts.ProfilePicture

  @fixture Path.expand("../../../fixtures/test_image.jpg", __DIR__)

  describe "ProfilePicture upload (action-level)" do
    test "actor can upload their own profile picture" do
      target = generate(user())

      upload = %Plug.Upload{
        path: @fixture,
        filename: "avatar.jpg",
        content_type: "image/jpeg"
      }

      assert {:ok, picture} =
               ProfilePicture
               |> Ash.Changeset.for_create(:upload, %{file: upload}, actor: target)
               |> Ash.create()

      assert picture.user_id == target.id
      assert picture.filename == "avatar.jpg"
      assert picture.content_type == "image/jpeg"
      assert is_integer(picture.size_bytes) and picture.size_bytes > 0
      assert is_binary(picture.storage_path)
      assert is_binary(picture.thumbnail_path)
    end
  end

  describe "POST /api/json/profile_pictures/upload" do
    test "route is registered and reachable", %{conn: conn} do
      target = generate(user())

      conn =
        conn
        |> authenticated_conn(target)
        |> put_req_header("content-type", "application/vnd.api+json")
        |> post("/api/json/profile_pictures/upload", %{
          "data" => %{
            "type" => "profile_picture",
            "attributes" => %{}
          }
        })

      # Route exists if status isn't 404. The action will reject the
      # missing :file argument with 422; what matters here is that
      # the JSON:API router accepted the path and forwarded to the action.
      refute conn.status == 404
    end
  end
end
