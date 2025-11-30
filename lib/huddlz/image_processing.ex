defmodule Huddlz.ImageProcessing do
  @moduledoc """
  Image processing utilities for resizing and optimizing uploads.
  """

  @thumbnail_size 256
  @banner_width 1280
  @banner_height 720

  @doc """
  Creates a square thumbnail from the given image binary.
  Returns {:ok, thumbnail_binary} or {:error, reason}.

  The thumbnail is always output as JPEG at 85% quality for optimal file size.
  Used for profile pictures and other square avatar-style images.
  """
  def create_thumbnail(image_binary) do
    with {:ok, image} <- Image.from_binary(image_binary),
         {:ok, thumbnail} <- Image.thumbnail(image, @thumbnail_size, crop: :center) do
      Image.write(thumbnail, :memory, suffix: ".jpg", quality: 85)
    end
  end

  @doc """
  Creates a banner thumbnail (16:9 aspect ratio) from the given image binary.
  Returns {:ok, thumbnail_binary} or {:error, reason}.

  Default size is 1280x720 (720p) which provides good quality for retina displays
  while keeping file sizes reasonable (~80-150KB).

  The thumbnail is always output as JPEG at 85% quality for optimal file size.
  Used for group images, event banners, and other wide-format images.
  """
  def create_banner_thumbnail(image_binary, width \\ @banner_width, height \\ @banner_height) do
    with {:ok, image} <- Image.from_binary(image_binary),
         {:ok, thumbnail} <- Image.thumbnail(image, "#{width}x#{height}", crop: :center) do
      Image.write(thumbnail, :memory, suffix: ".jpg", quality: 85)
    end
  end
end
