defmodule Huddlz.DateTimeFormattingTest do
  use ExUnit.Case, async: true

  alias Huddlz.DateTimeFormatting

  describe "resolve_zone/2" do
    test "prefers the user's preference over the huddl's own zone" do
      user = %{time_zone_preference: "America/Denver"}
      huddl = %{time_zone: "America/Chicago"}
      assert DateTimeFormatting.resolve_zone(user, huddl) == "America/Denver"
    end

    test "falls back to the huddl's zone when the user has no preference" do
      user = %{time_zone_preference: nil}
      huddl = %{time_zone: "America/Chicago"}
      assert DateTimeFormatting.resolve_zone(user, huddl) == "America/Chicago"
    end

    test "falls back to Etc/UTC with no user and no huddl zone" do
      assert DateTimeFormatting.resolve_zone(nil, nil) == "Etc/UTC"
      assert DateTimeFormatting.resolve_zone(nil, %{time_zone: nil}) == "Etc/UTC"
    end
  end

  describe "resolve_viewer_zone/2" do
    test "prefers the user's preference over the browser-detected zone" do
      user = %{time_zone_preference: "America/Denver"}
      assert DateTimeFormatting.resolve_viewer_zone(user, "America/Chicago") == "America/Denver"
    end

    test "falls back to the browser-detected zone with no preference" do
      assert DateTimeFormatting.resolve_viewer_zone(%{time_zone_preference: nil}, "America/Chicago") ==
               "America/Chicago"
    end

    test "falls back to Etc/UTC with neither" do
      assert DateTimeFormatting.resolve_viewer_zone(nil, nil) == "Etc/UTC"
    end
  end

  describe "shift/2" do
    test "shifts into the given zone" do
      dt = ~U[2030-05-04 17:00:00Z]
      shifted = DateTimeFormatting.shift(dt, "America/New_York")
      assert shifted.time_zone == "America/New_York"
      assert Calendar.strftime(shifted, "%-I:%M %p") == "1:00 PM"
    end

    test "falls back to Etc/UTC for an invalid zone" do
      dt = ~U[2030-05-04 17:00:00Z]
      shifted = DateTimeFormatting.shift(dt, "Nope/Nowhere")
      assert shifted.time_zone == "Etc/UTC"
    end

    test "falls back to Etc/UTC for a nil zone" do
      dt = ~U[2030-05-04 17:00:00Z]
      assert DateTimeFormatting.shift(dt, nil).time_zone == "Etc/UTC"
    end
  end
end
