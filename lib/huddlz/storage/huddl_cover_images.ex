defmodule Huddlz.Storage.HuddlCoverImages do
  @moduledoc """
  High-level helper for huddl image storage operations.
  Handles path generation, validation, thumbnail creation, and storage.

  Huddl images are stored as 16:9 banners (1280x720) for optimal display
  in card layouts and hero sections.
  """

  alias Huddlz.ImageProcessing
  alias Huddlz.Storage
  alias Huddlz.Storage.ImageUpload

  @prefix "huddl_cover_images"

  @doc """
  Store a huddl image from a source file path.
  Creates a thumbnail and stores both original and thumbnail.
  Returns {:ok, %{storage_path: ..., thumbnail_path: ..., size_bytes: ...}} or {:error, reason}.

  ## Parameters
  - source_path: Path to the temp file from upload
  - original_filename: Original filename from the client
  - content_type: MIME type of the file
  - huddl_id: ID of the huddl that owns the image
  """
  def store(source_path, original_filename, content_type, huddl_id) do
    ImageUpload.store(
      source_path,
      original_filename,
      content_type,
      generate_path(huddl_id, original_filename),
      &ImageProcessing.create_banner_thumbnail/1
    )
  end

  @doc """
  Store a pending huddl image (no huddl_id yet).
  Creates a thumbnail and stores both original and thumbnail in a pending path.
  Returns {:ok, %{storage_path: ..., thumbnail_path: ..., size_bytes: ...}} or {:error, reason}.

  ## Parameters
  - source_path: Path to the temp file from upload
  - original_filename: Original filename from the client
  - content_type: MIME type of the file
  """
  def store_pending(source_path, original_filename, content_type) do
    ImageUpload.store(
      source_path,
      original_filename,
      content_type,
      generate_pending_path(original_filename),
      &ImageProcessing.create_banner_thumbnail/1
    )
  end

  @doc """
  Copy a stored huddl image and its thumbnail to paths owned by another huddl.

  Returns metadata suitable for creating a `HuddlCoverImage` record. If either copy
  fails, any destination file already written is removed.
  """
  def duplicate(image, huddl_id) do
    storage_path = generate_path(huddl_id, image.filename)
    thumbnail_path = duplicate_thumbnail_path(image, storage_path)

    with {:ok, _path} <- Storage.copy(image.storage_path, storage_path, image.content_type),
         :ok <- duplicate_thumbnail(image.thumbnail_path, thumbnail_path) do
      {:ok,
       %{
         filename: image.filename,
         content_type: image.content_type,
         size_bytes: image.size_bytes,
         storage_path: storage_path,
         thumbnail_path: thumbnail_path
       }}
    else
      {:error, reason} ->
        delete(storage_path)
        delete(thumbnail_path)
        {:error, reason}
    end
  end

  @doc """
  Delete a huddl image by its storage path.
  """
  def delete(path) when is_binary(path) do
    Storage.delete(path)
  end

  def delete(nil), do: :ok

  @doc """
  Get the public URL for a huddl image path.
  """
  def url(nil), do: nil
  def url(path), do: Storage.url(path)

  @doc """
  Generate a unique storage path for a huddl image.
  Format: /uploads/huddl_cover_images/{huddl_id}/{uuid}.{ext}
  """
  def generate_path(huddl_id, original_filename) do
    ext = Path.extname(original_filename) |> String.downcase()
    uuid = Ecto.UUID.generate()
    "/uploads/#{@prefix}/#{huddl_id}/#{uuid}#{ext}"
  end

  @doc """
  Generate a unique storage path for a pending huddl image.
  Format: /uploads/huddl_cover_images/pending/{uuid}.{ext}
  """
  def generate_pending_path(original_filename) do
    ext = Path.extname(original_filename) |> String.downcase()
    uuid = Ecto.UUID.generate()
    "/uploads/#{@prefix}/pending/#{uuid}#{ext}"
  end

  @doc """
  Generate the thumbnail path from an original storage path.
  Replaces the extension with _thumb.jpg
  """
  def generate_thumbnail_path(original_path) do
    ImageUpload.thumbnail_path(original_path)
  end

  defp duplicate_thumbnail_path(thumbnail_path, storage_path) do
    if thumbnail_path, do: generate_thumbnail_path(storage_path)
  end

  defp duplicate_thumbnail(nil, nil), do: :ok

  defp duplicate_thumbnail(source_path, destination_path) do
    case Storage.copy(source_path, destination_path, "image/jpeg") do
      {:ok, _path} -> :ok
      {:error, reason} -> {:error, reason}
    end
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
