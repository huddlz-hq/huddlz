defmodule Huddlz.Storage.HuddlPhotos do
  @moduledoc """
  High-level helper for huddl photo storage operations (post-huddl gallery
  uploads). Handles path generation, validation, thumbnail creation, and storage.

  Grid thumbnails are square crops (256x256); the lightbox shows the original.
  """

  alias Huddlz.ImageProcessing
  alias Huddlz.Storage
  alias Huddlz.Storage.ImageUpload

  @prefix "huddl_photos"

  @doc """
  Store a huddl photo from a source file path.
  Creates a thumbnail and stores both original and thumbnail.
  Returns {:ok, %{storage_path: ..., thumbnail_path: ..., size_bytes: ...}} or {:error, reason}.
  """
  def store(source_path, original_filename, content_type, huddl_id) do
    ImageUpload.store(
      source_path,
      original_filename,
      content_type,
      generate_path(huddl_id, original_filename),
      &ImageProcessing.create_thumbnail/1
    )
  end

  @doc """
  Delete a huddl photo by its storage path.
  """
  def delete(path) when is_binary(path), do: Storage.delete(path)
  def delete(nil), do: :ok

  @doc """
  Get the public URL for a huddl photo path.
  """
  def url(nil), do: nil
  def url(path), do: Storage.url(path)

  @doc """
  Generate a unique storage path for a huddl photo.
  Format: /uploads/huddl_photos/{huddl_id}/{uuid}.{ext}
  """
  def generate_path(huddl_id, original_filename) do
    ext = Path.extname(original_filename) |> String.downcase()
    uuid = Ecto.UUID.generate()
    "/uploads/#{@prefix}/#{huddl_id}/#{uuid}#{ext}"
  end

  @doc """
  Generate the thumbnail path from an original storage path.
  Replaces the extension with _thumb.jpg
  """
  def generate_thumbnail_path(original_path) do
    ImageUpload.thumbnail_path(original_path)
  end

  @doc """
  Returns the list of allowed file extensions.
  """
  defdelegate allowed_extensions(), to: ImageUpload

  @doc """
  Returns the maximum file size in bytes.
  """
  defdelegate max_file_size(), to: ImageUpload

  @doc """
  Validates that the content type is an allowed image type.
  """
  defdelegate validate_file_type(content_type), to: ImageUpload
  defdelegate validate_file_size(size_bytes), to: ImageUpload
end
