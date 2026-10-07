defmodule Huddlz.TimeZoneTest do
  use ExUnit.Case, async: true

  alias Huddlz.TimeZone

  describe "resolve_local_forward/2" do
    test "moves a spring-forward gap to the first valid local time" do
      assert {:ok, resolved} =
               TimeZone.resolve_local_forward(~N[2030-03-10 02:30:00], "America/New_York")

      assert DateTime.to_time(resolved) == ~T[03:00:00]
      assert resolved.zone_abbr == "EDT"
    end

    test "leaves an ordinary local time alone" do
      assert {:ok, resolved} =
               TimeZone.resolve_local_forward(~N[2030-06-10 18:30:00], "America/New_York")

      assert DateTime.to_naive(resolved) == ~N[2030-06-10 18:30:00]
    end

    test "picks the earlier instant for an ambiguous fall-back time" do
      assert {:ok, resolved} =
               TimeZone.resolve_local_forward(~N[2030-11-03 01:30:00], "America/New_York")

      assert resolved.zone_abbr == "EDT"
    end

    test "still reports an unknown time zone" do
      assert {:error, :time_zone_not_found} =
               TimeZone.resolve_local_forward(~N[2030-06-10 18:30:00], "Not/AZone")
    end

    test "resolve_local/2 still rejects a gap, for times a person typed" do
      assert {:error, :daylight_saving_gap} =
               TimeZone.resolve_local(~N[2030-03-10 02:30:00], "America/New_York")
    end
  end
end
