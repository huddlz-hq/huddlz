defmodule HuddlzWeb.Live.Helpers.HuddlCardHelpersTest do
  use ExUnit.Case, async: true

  alias HuddlzWeb.Live.Helpers.HuddlCardHelpers

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
      assert timing(from_now(hour: -9), from_now(hour: -1)) == "1 hour ago"
      assert timing(from_now(hour: -33), from_now(hour: -25)) == "yesterday"
    end

    test "reads as just ended once the end has passed" do
      assert timing(from_now(hour: -2), from_now(second: -1)) == "just ended"
    end
  end

  defp timing(starts_at, ends_at) do
    HuddlCardHelpers.relative_time(%{starts_at: starts_at, ends_at: ends_at})
  end

  defp from_now(offsets) do
    Enum.reduce(offsets, DateTime.utc_now(), fn {unit, amount}, datetime ->
      DateTime.add(datetime, amount, unit)
    end)
  end
end
