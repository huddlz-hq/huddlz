defmodule HuddlzWeb.AuthReturnToTest do
  use ExUnit.Case, async: true

  alias HuddlzWeb.AuthReturnTo

  test "accepts local paths" do
    assert AuthReturnTo.validate("/groups/book-club/huddlz/123?tab=rsvp") ==
             "/groups/book-club/huddlz/123?tab=rsvp"
  end

  test "accepts encoded callback URLs inside a local path's query" do
    path =
      "/oauth/authorize?" <> URI.encode_query(redirect_uri: "http://localhost:54321/callback")

    assert AuthReturnTo.validate(path) == path
  end

  test "rejects external and malformed return paths" do
    for path <- [
          "https://evil.example",
          "//evil.example",
          "/\\evil.example",
          "/%5C%5Cevil.example",
          "/%2F%2Fevil.example?redirect_uri=http%3A%2F%2Flocalhost",
          "relative/path",
          nil
        ] do
      assert AuthReturnTo.validate(path) == nil
    end
  end
end
