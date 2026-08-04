defmodule Huddlz.Storage.HuddlPhotos do
  @moduledoc """
  High-level helper for huddl photo storage operations (post-huddl gallery
  uploads). Handles path generation, validation, thumbnail creation, and storage.

  Grid thumbnails are square crops (256x256); the lightbox shows the original.
  """

  alias Huddlz.ImageProcessing
  alias Huddlz.Storage

  @prefix "huddl_photos"
  @allowed_extensions ~w(.jpg .jpeg .png .webp)
  @max_file_size 5 * 1024 * 1024

  @doc """
  Store a huddl photo from a source file path.
  Creates a thumbnail and stores both original and thumbnail.
  Returns {:ok, %{storage_path: ..., thumbnail_path: ..., size_bytes: ...}} or {:error, reason}.
  """
  def store(source_path, original_filename, content_type, huddl_id) do
    with :ok <- validate_extension(original_filename),
         :ok <- validate_file_type(content_type),
         {:ok, %{size: size}} <- File.stat(source_path),
         :ok <- validate_file_size(size),
         {:ok, image_binary} <- File.read(source_path),
         {:ok, thumbnail_binary} <- ImageProcessing.create_thumbnail(image_binary),
         storage_path = generate_path(huddl_id, original_filename),
         thumbnail_path = generate_thumbnail_path(storage_path),
         {:ok, _} <- Storage.put(source_path, storage_path, content_type),
         :ok <- store_thumbnail(thumbnail_binary, thumbnail_path) do
      {:ok,
       %{
         storage_path: storage_path,
         thumbnail_path: thumbnail_path,
         size_bytes: size
       }}
    end
  end

  defp store_thumbnail(binary, path) do
    temp_path = Path.join(System.tmp_dir!(), "thumb_#{:erlang.unique_integer([:positive])}.jpg")

    try do
      File.write!(temp_path, binary)

      case Storage.put(temp_path, path, "image/jpeg") do
        {:ok, _} -> :ok
        {:error, reason} -> {:error, reason}
      end
    after
      File.rm(temp_path)
    end
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
    String.replace(original_path, ~r/\.\w+$/, "_thumb.jpg")
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
