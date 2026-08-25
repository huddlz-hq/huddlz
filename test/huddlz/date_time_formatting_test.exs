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
      assert DateTimeFormatting.resolve_viewer_zone(
               %{time_zone_preference: nil},
               "America/Chicago"
             ) ==
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

  describe "resolve_wall_time/3" do
    test "resolves an ordinary wall time in the given zone" do
      assert {:ok, datetime} =
               DateTimeFormatting.resolve_wall_time(
                 ~D[2027-06-15],
                 ~T[19:00:00],
                 "America/New_York"
               )

      assert DateTime.shift_zone!(datetime, "Etc/UTC") == ~U[2027-06-15 23:00:00Z]
    end

    test "takes the earlier instant for a fall-back ambiguous wall time" do
      assert {:ok, datetime} =
               DateTimeFormatting.resolve_wall_time(
                 ~D[2027-11-07],
                 ~T[01:30:00],
                 "America/New_York"
               )

      assert DateTime.shift_zone!(datetime, "Etc/UTC") == ~U[2027-11-07 05:30:00Z]
    end

    test "reports a spring-forward gap instead of raising" do
      assert {:gap, just_before, just_after} =
               DateTimeFormatting.resolve_wall_time(
                 ~D[2027-03-14],
                 ~T[02:30:00],
                 "America/New_York"
               )

      assert DateTime.shift_zone!(just_before, "Etc/UTC") == ~U[2027-03-14 06:59:59.999999Z]
      assert DateTime.shift_zone!(just_after, "Etc/UTC") == ~U[2027-03-14 07:00:00Z]
    end

    test "falls back to Etc/UTC for a nil zone" do
      assert {:ok, datetime} =
               DateTimeFormatting.resolve_wall_time(~D[2027-06-15], ~T[19:00:00], nil)

      assert datetime == ~U[2027-06-15 19:00:00Z]
    end
  end
end
