defmodule Huddlz.StorageTest do
  use ExUnit.Case, async: true

  alias Huddlz.Storage.Local

  describe "Storage.Local" do
    setup do
      # Create a unique test directory
      test_id = :rand.uniform(999_999)

      on_exit(fn ->
        File.rm_rf!("priv/static/uploads/test_#{test_id}")
      end)

      {:ok, test_id: test_id}
    end

    test "put/3 stores a file and returns the path", %{test_id: test_id} do
      # Create a temp file with content
      temp_path = Path.join(System.tmp_dir!(), "test_file_#{test_id}.txt")
      File.write!(temp_path, "test content")

      on_exit(fn -> File.rm(temp_path) end)

      storage_path = "/uploads/test_#{test_id}/stored_file.txt"

      assert {:ok, ^storage_path} = Local.put(temp_path, storage_path, "text/plain")

      # Verify file exists in target location
      full_path = Path.join("priv/static", storage_path)
      assert File.exists?(full_path)
      assert File.read!(full_path) == "test content"
    end

    test "delete/1 removes a file", %{test_id: test_id} do
      # Create a file to delete
      storage_path = "/uploads/test_#{test_id}/to_delete.txt"
      full_path = Path.join("priv/static", storage_path)
      File.mkdir_p!(Path.dirname(full_path))
      File.write!(full_path, "delete me")

      assert File.exists?(full_path)
      assert :ok = Local.delete(storage_path)
      refute File.exists?(full_path)
    end

    test "delete/1 returns ok for non-existent file", %{test_id: test_id} do
      storage_path = "/uploads/test_#{test_id}/nonexistent.txt"
      assert :ok = Local.delete(storage_path)
    end

    test "exists?/1 returns true for existing file", %{test_id: test_id} do
      storage_path = "/uploads/test_#{test_id}/exists.txt"
      full_path = Path.join("priv/static", storage_path)
      File.mkdir_p!(Path.dirname(full_path))
      File.write!(full_path, "I exist")

      assert Local.exists?(storage_path)
    end

    test "exists?/1 returns false for non-existent file", %{test_id: test_id} do
      storage_path = "/uploads/test_#{test_id}/not_exists.txt"
      refute Local.exists?(storage_path)
    end

    test "url/1 returns the storage path as-is" do
      storage_path = "/uploads/profile_pictures/user123/avatar.jpg"
      assert Local.url(storage_path) == storage_path
    end
  end

  describe "Storage.ProfilePictures" do
    alias Huddlz.Storage.ProfilePictures

    setup do
      test_id = :rand.uniform(999_999)
      user_id = "test-user-#{test_id}"

      on_exit(fn ->
        File.rm_rf!("priv/static/uploads/profile_pictures/#{user_id}")
      end)

      {:ok, test_id: test_id, user_id: user_id}
    end

    test "store/4 stores file from source path and returns storage metadata", %{
      test_id: test_id,
      user_id: user_id
    } do
      # Create a temp file simulating an upload
      temp_path = Path.join(System.tmp_dir!(), "upload_#{test_id}.png")
      # Write a minimal valid PNG (1x1 transparent pixel)
      png_content =
        Base.decode64!(
          "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
        )

      File.write!(temp_path, png_content)
      on_exit(fn -> File.rm(temp_path) end)

      # Call store with (source_path, original_filename, content_type, user_id)
      assert {:ok, metadata} =
               ProfilePictures.store(temp_path, "avatar.png", "image/png", user_id)

      # Verify the metadata structure
      assert %{storage_path: storage_path, thumbnail_path: thumbnail_path, size_bytes: size} =
               metadata

      assert storage_path =~ "/uploads/profile_pictures/#{user_id}/"
      assert storage_path =~ ~r/\.png$/
      assert thumbnail_path =~ "/uploads/profile_pictures/#{user_id}/"
      assert thumbnail_path =~ ~r/_thumb\.jpg$/
      assert size == byte_size(png_content)

      # Verify the original file was stored
      full_path = Path.join("priv/static", storage_path)
      assert File.exists?(full_path)
      assert File.read!(full_path) == png_content

      # Verify the thumbnail was stored
      thumb_full_path = Path.join("priv/static", thumbnail_path)
      assert File.exists?(thumb_full_path)
    end

    test "store/4 rejects invalid file extensions", %{test_id: test_id, user_id: user_id} do
      temp_path = Path.join(System.tmp_dir!(), "upload_#{test_id}.gif")
      File.write!(temp_path, "fake gif content")
      on_exit(fn -> File.rm(temp_path) end)

      assert {:error, :invalid_extension} =
               ProfilePictures.store(temp_path, "avatar.gif", "image/gif", user_id)
    end

    test "store/4 rejects files that are too large", %{test_id: test_id, user_id: user_id} do
      temp_path = Path.join(System.tmp_dir!(), "upload_#{test_id}.png")
      # Create a file larger than 5MB
      large_content = :binary.copy(<<0>>, 6 * 1024 * 1024)
      File.write!(temp_path, large_content)
      on_exit(fn -> File.rm(temp_path) end)

      assert {:error, "File too large. Maximum size: 5MB"} =
               ProfilePictures.store(temp_path, "large.png", "image/png", user_id)
    end

    test "generate_path/2 generates correct path structure" do
      user_id = "user-123-456"
      filename = "my_avatar.jpg"

      path = ProfilePictures.generate_path(user_id, filename)

      assert path =~ "/uploads/profile_pictures/"
      assert path =~ user_id
      assert path =~ ~r/\.jpg$/
    end

    test "generate_path/2 preserves file extension" do
      user_id = "user-789"

      assert ProfilePictures.generate_path(user_id, "test.png") =~ ~r/\.png$/
      assert ProfilePictures.generate_path(user_id, "test.webp") =~ ~r/\.webp$/
      assert ProfilePictures.generate_path(user_id, "test.jpeg") =~ ~r/\.jpeg$/
    end

    test "url/1 delegates to storage adapter" do
      storage_path = "/uploads/profile_pictures/user123/avatar.jpg"
      # In test/dev, this uses local storage
      url = ProfilePictures.url(storage_path)

      # Local storage returns the path as-is
      assert url == storage_path
    end

    test "validate_file_type/1 allows valid image types" do
      assert ProfilePictures.validate_file_type("image/jpeg") == :ok
      assert ProfilePictures.validate_file_type("image/png") == :ok
      assert ProfilePictures.validate_file_type("image/webp") == :ok
    end

    test "validate_file_type/1 rejects invalid types" do
      assert {:error, _} = ProfilePictures.validate_file_type("text/plain")
      assert {:error, _} = ProfilePictures.validate_file_type("application/pdf")
      assert {:error, _} = ProfilePictures.validate_file_type("image/gif")
    end

    test "validate_file_size/1 allows files under 5MB" do
      # 5MB = 5 * 1024 * 1024 = 5,242,880 bytes
      assert ProfilePictures.validate_file_size(1_000) == :ok
      assert ProfilePictures.validate_file_size(5_242_879) == :ok
    end

    test "validate_file_size/1 rejects files over 5MB" do
      # 5MB = 5 * 1024 * 1024 = 5,242,880 bytes
      assert {:error, _} = ProfilePictures.validate_file_size(5_242_881)
      assert {:error, _} = ProfilePictures.validate_file_size(10_000_000)
    end
  end
end
