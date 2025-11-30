defmodule Huddlz.ImageProcessing do
  @moduledoc """
  Image processing utilities for resizing and optimizing uploads.
  """

  @thumbnail_size 256

  @doc """
  Creates a thumbnail from the given image binary.
  Returns {:ok, thumbnail_binary} or {:error, reason}.

  The thumbnail is always output as JPEG at 85% quality for optimal file size.
  """
  def create_thumbnail(image_binary) do
    with {:ok, image} <- Image.from_binary(image_binary),
         {:ok, thumbnail} <- Image.thumbnail(image, @thumbnail_size, crop: :center) do
      Image.write(thumbnail, :memory, suffix: ".jpg", quality: 85)
    end
  end
end
