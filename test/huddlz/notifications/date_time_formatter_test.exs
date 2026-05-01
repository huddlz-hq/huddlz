defmodule Huddlz.Notifications.DateTimeFormatterTest do
  use ExUnit.Case, async: true

  alias Huddlz.Notifications.DateTimeFormatter

  describe "format_starts_at/2" do
    test "defaults to UTC" do
      starts_at = ~U[2030-05-04 17:00:00Z]

      assert DateTimeFormatter.format_starts_at(starts_at) ==
               "Sat May 4, 2030 at 5:00 PM UTC"
    end

    test "formats in the requested time zone" do
      starts_at = ~U[2030-05-04 17:00:00Z]

      assert DateTimeFormatter.format_starts_at(starts_at, "America/New_York") ==
               "Sat May 4, 2030 at 1:00 PM EDT"
    end

    test "falls back to UTC for an invalid time zone" do
      starts_at = ~U[2030-05-04 17:00:00Z]

      assert DateTimeFormatter.format_starts_at(starts_at, "Nope/Nowhere") ==
               "Sat May 4, 2030 at 5:00 PM UTC"
    end
  end

  describe "format_starts_at_iso/3" do
    test "formats valid ISO datetimes with the requested time zone" do
      assert DateTimeFormatter.format_starts_at_iso(
               "2030-05-04T17:00:00Z",
               "America/Los_Angeles"
             ) == "Sat May 4, 2030 at 10:00 AM PDT"
    end

    test "returns the supplied fallback for invalid ISO values" do
      assert DateTimeFormatter.format_starts_at_iso("soon", "America/New_York", "soon") ==
               "soon"
    end
  end
end
