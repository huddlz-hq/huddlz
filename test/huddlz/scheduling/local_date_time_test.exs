defmodule Huddlz.Scheduling.LocalDateTimeTest do
  use ExUnit.Case, async: true

  alias Huddlz.Scheduling.LocalDateTime

  describe "resolve/4" do
    test "advances a New York spring-forward gap by one hour" do
      assert {:ok, resolution} =
               LocalDateTime.resolve(
                 ~D[2027-03-14],
                 ~T[02:30:00],
                 "America/New_York"
               )

      assert resolution.kind == :gap
      assert resolution.requested == ~N[2027-03-14 02:30:00]
      assert resolution.selected.zone_abbr == "EDT"

      assert DateTime.shift_zone!(resolution.selected, "Etc/UTC") ==
               ~U[2027-03-14 07:30:00Z]
    end

    test "returns both New York fall-back occurrences and selects the requested one" do
      assert {:ok, earlier_resolution} =
               LocalDateTime.resolve(
                 ~D[2027-11-07],
                 ~T[01:30:00],
                 "America/New_York"
               )

      assert earlier_resolution.kind == :ambiguous
      assert earlier_resolution.selected == earlier_resolution.earlier
      assert earlier_resolution.earlier.zone_abbr == "EDT"
      assert earlier_resolution.later.zone_abbr == "EST"

      assert DateTime.shift_zone!(earlier_resolution.earlier, "Etc/UTC") ==
               ~U[2027-11-07 05:30:00Z]

      assert DateTime.shift_zone!(earlier_resolution.later, "Etc/UTC") ==
               ~U[2027-11-07 06:30:00Z]

      assert {:ok, later_resolution} =
               LocalDateTime.resolve(
                 ~D[2027-11-07],
                 ~T[01:30:00],
                 "America/New_York",
                 :later
               )

      assert later_resolution.selected == later_resolution.later
    end
  end
end
