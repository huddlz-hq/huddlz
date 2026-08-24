defmodule Huddlz.Geocoding.TimeZoneLookupTest do
  use ExUnit.Case, async: true

  alias Huddlz.Geocoding.TimeZoneLookup

  describe "from_coordinates/2" do
    test "resolves a known point to its IANA zone" do
      # Austin, TX
      assert TimeZoneLookup.from_coordinates(30.27, -97.74) == {:ok, "America/Chicago"}
    end

    test "resolves a different known point to its own zone" do
      # Saint Augustine, FL
      assert TimeZoneLookup.from_coordinates(29.89, -81.31) == {:ok, "America/New_York"}
    end

    test "returns :error for coordinates with no timezone polygon (open ocean)" do
      assert TimeZoneLookup.from_coordinates(0.0, -160.0) == :error
    end
  end
end
