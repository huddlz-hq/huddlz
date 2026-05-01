defmodule Huddlz.Notifications.Senders.HeaderSafeTest do
  use ExUnit.Case, async: true

  alias Huddlz.Notifications.Senders.HeaderSafe

  doctest HeaderSafe

  test "replaces CR and LF with spaces (header injection vector)" do
    assert HeaderSafe.safe("Alice\r\nBcc: x@evil.com") == "Alice Bcc: x@evil.com"
  end

  test "replaces NUL, tab, vertical tab, and DEL" do
    assert HeaderSafe.safe("a\x00b\tc\vd\x7fe") == "a b c d e"
  end

  test "collapses runs of whitespace to a single space" do
    assert HeaderSafe.safe("hello   world") == "hello world"
  end

  test "trims leading and trailing whitespace" do
    assert HeaderSafe.safe("  padded  ") == "padded"
  end

  test "preserves non-ASCII unicode" do
    assert HeaderSafe.safe("Café résumé 🎉") == "Café résumé 🎉"
  end

  test "coerces non-string input via to_string/1" do
    assert HeaderSafe.safe(42) == "42"
    assert HeaderSafe.safe(nil) == ""
  end
end
