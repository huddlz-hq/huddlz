defmodule Huddlz.ImageUploadTest do
  use ExUnit.Case, async: true

  alias Huddlz.ImageProcessing
  alias Huddlz.Storage
  alias Huddlz.Storage.{HuddlCoverImages, HuddlPhotos, ImageUpload}

  test "a failed thumbnail write removes the newly stored original" do
    directory = "/uploads/image-upload-test/#{Ecto.UUID.generate()}"
    destination = directory <> "/photo.jpg"
    # A directory where the thumbnail should be makes the real adapter fail.
    File.mkdir_p!(Path.join("priv/static", ImageUpload.thumbnail_path(destination)))
    on_exit(fn -> File.rm_rf!(Path.join("priv/static", directory)) end)

    assert {:error, _} =
             ImageUpload.store(
               "test/fixtures/test_image.jpg",
               "photo.jpg",
               "image/jpeg",
               destination,
               &ImageProcessing.create_thumbnail/1
             )

    refute Storage.exists?(destination)
  end

  test "cover and gallery uploads agree on the advertised five megabyte limit" do
    for storage <- [HuddlCoverImages, HuddlPhotos] do
      assert :ok = storage.validate_file_size(5_000_000)
      assert {:error, _} = storage.validate_file_size(5_000_001)
    end
  end
end
