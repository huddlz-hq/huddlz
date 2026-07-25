defmodule HuddlzWeb.AuthReturnToTest do
  use ExUnit.Case, async: true

  alias HuddlzWeb.AuthReturnTo

  test "accepts local paths" do
    assert AuthReturnTo.validate("/groups/book-club/huddlz/123?tab=rsvp") ==
             "/groups/book-club/huddlz/123?tab=rsvp"
  end

  test "rejects external and malformed return paths" do
    for path <- [
          "https://evil.example",
          "//evil.example",
          "/\\evil.example",
          "/%5C%5Cevil.example",
          "relative/path",
          nil
        ] do
      assert AuthReturnTo.validate(path) == nil
    end
  end
end
