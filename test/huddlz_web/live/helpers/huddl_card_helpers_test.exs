defmodule HuddlzWeb.Live.Helpers.HuddlCardHelpersTest do
  use ExUnit.Case, async: true

  alias HuddlzWeb.Live.Helpers.HuddlCardHelpers

  @now ~U[2026-09-15 12:00:00Z]

  describe "relative_time/2 with local calendar dates" do
    test "September 17 is two days away on the evening of September 15" do
      for starts_at <- [~U[2026-09-17 13:00:00Z], ~U[2026-09-17 22:30:00Z]] do
        assert local_timing(starts_at, ~U[2026-09-16 01:57:00Z]) == "2 days away"
      end
    end

    test "the calendar's display zone takes precedence over the huddl's zone" do
      huddl = %{
        starts_at: ~U[2026-09-17 13:00:00Z],
        ends_at: ~U[2026-09-17 14:00:00Z],
        time_zone: "Etc/UTC"
      }

      now = ~U[2026-09-16 01:57:00Z]
      assert HuddlCardHelpers.relative_time(huddl, now: now) == "tomorrow"

      assert HuddlCardHelpers.relative_time(huddl,
               now: now,
               time_zone: "America/New_York"
             ) == "2 days away"
    end

    test "yesterday also counts local dates from the end of the huddl" do
      huddl = %{
        starts_at: ~U[2026-09-15 02:00:00Z],
        ends_at: ~U[2026-09-15 03:00:00Z],
        time_zone: "America/New_York"
      }

      assert HuddlCardHelpers.relative_time(huddl, now: ~U[2026-09-16 12:00:00Z]) ==
               "Ended 2 days ago"
    end

    test "calendar days survive the spring daylight-saving change" do
      assert local_timing(~U[2026-03-09 04:00:00Z], ~U[2026-03-07 17:00:00Z]) ==
               "2 days away"

      assert local_timing(~U[2026-03-09 04:00:00Z], ~U[2026-03-08 04:30:00Z]) ==
               "2 days away"
    end

    test "calendar days survive the autumn daylight-saving change" do
      assert local_timing(~U[2026-11-02 05:00:00Z], ~U[2026-10-31 16:00:00Z]) ==
               "2 days away"
    end

    test "a 25-hour local day never displays zero days away" do
      assert local_timing(~U[2026-11-02 04:30:00Z], ~U[2026-11-01 04:00:00Z]) ==
               "24 hours away"
    end
  end

  defp local_timing(starts_at, now) do
    HuddlCardHelpers.relative_time(
      %{
        starts_at: starts_at,
        ends_at: DateTime.add(starts_at, 3600),
        time_zone: "America/New_York"
      },
      now: now
    )
  end

  describe "relative_time/1" do
    test "counts a huddl still to come down from when it starts" do
      assert timing(from_now(hour: 3, minute: 30), from_now(hour: 5)) == "3 hours away"
      assert timing(from_now(day: 1, hour: 2), from_now(day: 1, hour: 3)) == "tomorrow"
      assert timing(from_now(minute: 10), from_now(hour: 1)) == "starting soon"
    end

    test "says a huddl under way is happening now" do
      assert timing(from_now(minute: -20), from_now(minute: 40)) == "happening now"
    end

    test "says a long huddl is happening now well after it started" do
      assert timing(from_now(hour: -3), from_now(hour: 5)) == "happening now"
    end

    test "is happening now from the moment a huddl starts" do
      assert timing(from_now(second: 0), from_now(hour: 1)) == "happening now"
    end

    test "counts a finished huddl up from when it ended, not from when it started" do
      assert timing(from_now(hour: -9), from_now(hour: -1)) == "Ended 1 hour ago"
      assert timing(from_now(hour: -33), from_now(hour: -25)) == "Ended yesterday"
    end

    test "makes the end reference explicit beside a morning start time" do
      huddl = %{
        starts_at: ~U[2026-09-17 13:00:00Z],
        ends_at: ~U[2026-09-17 16:00:00Z],
        time_zone: "America/New_York"
      }

      assert HuddlCardHelpers.relative_time(huddl, now: ~U[2026-09-18 00:52:00Z]) ==
               "Ended 8 hours ago"
    end

    test "reads as just ended once the end has passed" do
      assert timing(from_now(hour: -2), from_now(second: -1)) == "just ended"
    end
  end

  defp timing(starts_at, ends_at) do
    HuddlCardHelpers.relative_time(%{starts_at: starts_at, ends_at: ends_at}, now: @now)
  end

  defp from_now(offsets) do
    Enum.reduce(offsets, @now, fn {unit, amount}, datetime ->
      DateTime.add(datetime, amount, unit)
    end)
  end
end
