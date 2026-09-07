defmodule Huddlz.Storage.ImageUpload do
  @moduledoc """
  Shared validation and storage for originals with generated JPEG thumbnails.
  Removes a newly stored original if its thumbnail cannot be saved.
  """
  alias Huddlz.Storage

  @extensions ~w(.jpg .jpeg .png .webp)
  @max_file_size 5_000_000

  def allowed_extensions, do: @extensions
  def max_file_size, do: @max_file_size

  def validate_file_type(type) when type in ~w(image/jpeg image/png image/webp), do: :ok
  def validate_file_type(_), do: {:error, "Invalid file type. Allowed: JPG, PNG, WebP"}
  def validate_file_size(size) when size <= @max_file_size, do: :ok
  def validate_file_size(_), do: {:error, :too_large}

  def thumbnail_path(path), do: String.replace(path, ~r/\.\w+$/, "_thumb.jpg")

  def store(source, filename, type, destination, thumbnail) do
    with :ok <- validate_extension(filename),
         :ok <- validate_file_type(type),
         {:ok, %{size: size}} <- File.stat(source),
         :ok <- validate_file_size(size),
         {:ok, binary} <- File.read(source),
         {:ok, preview} <- create_thumbnail(binary, thumbnail),
         {:ok, _} <- Storage.put(source, destination, type) do
      save_thumbnail(preview, destination, size)
    end
  end

  defp validate_extension(filename) do
    if String.downcase(Path.extname(filename)) in @extensions,
      do: :ok,
      else: {:error, :invalid_extension}
  end

  defp create_thumbnail(binary, thumbnail) do
    case thumbnail.(binary) do
      {:ok, preview} -> {:ok, preview}
      {:error, _} -> {:error, :invalid_image}
    end
  end

  defp save_thumbnail(binary, destination, size) do
    path = thumbnail_path(destination)
    temp = Path.join(System.tmp_dir!(), "thumb_#{Ecto.UUID.generate()}.jpg")

    try do
      with :ok <- File.write(temp, binary),
           {:ok, _} <- Storage.put(temp, path, "image/jpeg") do
        {:ok, %{storage_path: destination, thumbnail_path: path, size_bytes: size}}
      else
        {:error, reason} ->
          Storage.delete(destination)
          Storage.delete(path)
          {:error, reason}
      end
    after
      File.rm(temp)
    end
  end
end
