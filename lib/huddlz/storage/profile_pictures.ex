defmodule Huddlz.Storage.ProfilePictures do
  @moduledoc """
  High-level helper for profile picture storage operations.
  Handles path generation, validation, and storage.
  """

  alias Huddlz.Storage

  @prefix "profile_pictures"
  @allowed_extensions ~w(.jpg .jpeg .png .webp)
  @max_file_size 5 * 1024 * 1024

  @doc """
  Store a profile picture for a user from a source file path.
  Returns {:ok, storage_path} or {:error, reason}.

  ## Parameters
  - source_path: Path to the temp file from upload
  - original_filename: Original filename from the client
  - content_type: MIME type of the file
  - user_id: ID of the user who owns the picture
  """
  def store(source_path, original_filename, content_type, user_id) do
    with :ok <- validate_extension(original_filename),
         {:ok, %{size: size}} <- File.stat(source_path),
         :ok <- validate_file_size(size),
         storage_path <- generate_path(user_id, original_filename) do
      Storage.put(source_path, storage_path, content_type)
    end
  end

  @doc """
  Delete a profile picture by its storage path.
  """
  def delete(path) when is_binary(path) do
    Storage.delete(path)
  end

  def delete(nil), do: :ok

  @doc """
  Get the public URL for a profile picture path.
  """
  def url(nil), do: nil
  def url(path), do: Storage.url(path)

  @doc """
  Generate a unique storage path for a profile picture.
  Format: /uploads/profile_pictures/{user_id}/{uuid}.{ext}
  """
  def generate_path(user_id, original_filename) do
    ext = Path.extname(original_filename) |> String.downcase()
    uuid = Ecto.UUID.generate()
    "/uploads/#{@prefix}/#{user_id}/#{uuid}#{ext}"
  end

  @doc """
  Returns the list of allowed file extensions.
  """
  def allowed_extensions, do: @allowed_extensions

  @doc """
  Returns the maximum file size in bytes.
  """
  def max_file_size, do: @max_file_size

  @doc """
  Validates that the content type is an allowed image type.
  """
  def validate_file_type(content_type) do
    allowed_types = ~w(image/jpeg image/png image/webp)

    if content_type in allowed_types do
      :ok
    else
      {:error, "Invalid file type. Allowed: JPG, PNG, WebP"}
    end
  end

  @doc """
  Validates that the file size is within the allowed limit.
  """
  def validate_file_size(size_bytes) when size_bytes <= @max_file_size, do: :ok
  def validate_file_size(_), do: {:error, "File too large. Maximum size: 5MB"}

  defp validate_extension(filename) do
    ext = Path.extname(filename) |> String.downcase()

    if ext in @allowed_extensions do
      :ok
    else
      {:error, :invalid_extension}
    end
  end
end
