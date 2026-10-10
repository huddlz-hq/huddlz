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

  describe "sign_in_path/1" do
    test "returns to the requested page, keeping its query" do
      uri = URI.parse("https://huddlz.com/discover?yours=attending")

      assert AuthReturnTo.sign_in_path(uri) ==
               "/sign-in?return_to=%2Fdiscover%3Fyours%3Dattending"
    end

    test "returns to a requested page with no query" do
      assert AuthReturnTo.sign_in_path(URI.parse("https://huddlz.com/notifications")) ==
               "/sign-in?return_to=%2Fnotifications"
    end

    test "drops an empty query rather than returning to a bare question mark" do
      assert AuthReturnTo.sign_in_path(URI.parse("https://huddlz.com/profile?")) ==
               "/sign-in?return_to=%2Fprofile"
    end

    test "falls back to the bare sign-in address for unsafe or missing destinations" do
      for destination <- [URI.parse("https://huddlz.com//evil.example"), "//evil.example", nil] do
        assert AuthReturnTo.sign_in_path(destination) == "/sign-in"
      end
    end
  end
end
