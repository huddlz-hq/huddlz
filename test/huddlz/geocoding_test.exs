defmodule Huddlz.GeocodingTest do
  use ExUnit.Case, async: true

  describe "distance_miles/2" do
    test "calculates distance between Austin and Houston" do
      austin = {30.2672, -97.7431}
      houston = {29.7604, -95.3698}

      distance = Huddlz.Geocoding.distance_miles(austin, houston)

      # ~146 miles
      assert distance > 140
      assert distance < 155
    end

    test "returns 0 for same location" do
      point = {30.2672, -97.7431}
      assert Huddlz.Geocoding.distance_miles(point, point) == 0.0
    end

    test "calculates distance between New York and Los Angeles" do
      nyc = {40.7128, -74.0060}
      la = {34.0522, -118.2437}

      distance = Huddlz.Geocoding.distance_miles(nyc, la)

      # ~2,451 miles
      assert distance > 2400
      assert distance < 2500
    end
  end

  describe "error_message/1" do
    test "returns location not found message for :not_found" do
      assert Huddlz.Geocoding.error_message(:not_found) ==
               "Could not find that location. Try a more specific address."
    end

    test "returns unavailable message for other reasons" do
      assert Huddlz.Geocoding.error_message({:api_error, "REQUEST_DENIED"}) ==
               "Location search is currently unavailable."

      assert Huddlz.Geocoding.error_message({:request_failed, :timeout}) ==
               "Location search is currently unavailable."
    end
  end
end
