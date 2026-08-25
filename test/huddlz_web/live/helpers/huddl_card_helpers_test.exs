defmodule HuddlzWeb.Live.Helpers.HuddlCardHelpersTest do
  use ExUnit.Case, async: true

  alias HuddlzWeb.Live.Helpers.HuddlCardHelpers

  describe "format_meta_when/2" do
    test "shifts into the huddl's own time zone when the viewer has no preference" do
      huddl = %{starts_at: ~U[2030-05-04 17:00:00Z], time_zone: "America/New_York"}
      assert HuddlCardHelpers.format_meta_when(huddl, nil) =~ "1:00 PM"
    end

    test "shifts into the viewer's preferred zone when set" do
      huddl = %{starts_at: ~U[2030-05-04 17:00:00Z], time_zone: "America/New_York"}
      user = %{time_zone_preference: "America/Los_Angeles"}
      assert HuddlCardHelpers.format_meta_when(huddl, user) =~ "10:00 AM"
    end
  end

  describe "huddl_month/2 and huddl_day/2" do
    test "shift the calendar date into the resolved zone, not raw UTC" do
      # 2030-01-01 03:00 UTC is still Dec 31 in America/Los_Angeles.
      huddl = %{starts_at: ~U[2030-01-01 03:00:00Z], time_zone: "America/Los_Angeles"}

      assert HuddlCardHelpers.huddl_month(huddl, nil) == "DEC"
      assert HuddlCardHelpers.huddl_day(huddl, nil) == "31"
    end
  end
end
