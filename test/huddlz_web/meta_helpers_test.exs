defmodule HuddlzWeb.MetaHelpersTest do
  use ExUnit.Case, async: true

  alias HuddlzWeb.MetaHelpers

  defmodule PathStorage do
    def url(path), do: path
  end

  defmodule AbsoluteStorage do
    def url(_path), do: "https://cdn.example.com/uploads/preview.jpg"
  end

  describe "description/3" do
    test "uses the fallback for nil descriptions" do
      assert MetaHelpers.description(%{description: nil}, "Fallback text") == "Fallback text"
    end

    test "normalizes whitespace" do
      assert MetaHelpers.description(%{description: "  One\n\n two\tthree  "}, "Fallback text") ==
               "One two three"
    end

    test "truncates long descriptions at a word boundary" do
      assert MetaHelpers.description(%{description: "one two three four"}, "Fallback text", 13) ==
               "one two..."
    end

    test "uses the fallback when a description is blank after trimming" do
      assert MetaHelpers.description(%{description: "   "}, "Fallback text") == "Fallback text"
    end
  end

  describe "image_url/2" do
    test "returns nil when no image path is available" do
      assert MetaHelpers.image_url(nil, PathStorage) == nil
    end

    test "turns local storage paths into absolute URLs" do
      assert MetaHelpers.image_url("/uploads/preview.jpg", PathStorage) ==
               HuddlzWeb.Endpoint.url() <> "/uploads/preview.jpg"
    end

    test "keeps already absolute storage URLs" do
      assert MetaHelpers.image_url("/uploads/preview.jpg", AbsoluteStorage) ==
               "https://cdn.example.com/uploads/preview.jpg"
    end
  end
end
