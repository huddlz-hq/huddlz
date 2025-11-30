defmodule Huddlz.ImageProcessingTest do
  use ExUnit.Case, async: true

  alias Huddlz.ImageProcessing

  describe "create_thumbnail/1" do
    test "creates a 256px thumbnail from image binary" do
      {:ok, binary} = File.read("test/fixtures/test_image.jpg")

      assert {:ok, thumbnail} = ImageProcessing.create_thumbnail(binary)
      assert is_binary(thumbnail)

      # Verify it's smaller than original
      assert byte_size(thumbnail) < byte_size(binary)

      # Verify dimensions using Image library
      {:ok, image} = Image.from_binary(thumbnail)
      {width, height, _bands} = Image.shape(image)
      assert max(width, height) == 256
    end

    test "returns error for invalid image data" do
      assert {:error, _} = ImageProcessing.create_thumbnail("not an image")
    end
  end
end
