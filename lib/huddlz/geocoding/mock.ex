defmodule Huddlz.Geocoding.Mock do
  @moduledoc """
  Mock geocoding implementation for testing. Returns predictable coordinates
  for known addresses to ensure consistent test results.
  """
  @behaviour Huddlz.Geocoding.Behaviour

  @known_locations %{
    "New York, NY" => %{lat: 40.7128, lng: -74.0060},
    "Los Angeles, CA" => %{lat: 34.0522, lng: -118.2437},
    "Chicago, IL" => %{lat: 41.8781, lng: -87.6298},
    "Houston, TX" => %{lat: 29.7604, lng: -95.3698},
    "Phoenix, AZ" => %{lat: 33.4484, lng: -112.0740},
    "Philadelphia, PA" => %{lat: 39.9526, lng: -75.1652},
    "San Antonio, TX" => %{lat: 29.4241, lng: -98.4936},
    "San Diego, CA" => %{lat: 32.7157, lng: -117.1611},
    "Dallas, TX" => %{lat: 32.7767, lng: -96.7970},
    "San Jose, CA" => %{lat: 37.3382, lng: -121.8863},
    "Austin, TX" => %{lat: 30.2672, lng: -97.7431},
    "San Francisco, CA" => %{lat: 37.7749, lng: -122.4194},
    "Seattle, WA" => %{lat: 47.6062, lng: -122.3321},
    "Denver, CO" => %{lat: 39.7392, lng: -104.9903},
    "Boston, MA" => %{lat: 42.3601, lng: -71.0589},
    "Miami, FL" => %{lat: 25.7617, lng: -80.1918},
    "Atlanta, GA" => %{lat: 33.7490, lng: -84.3880},
    "Portland, OR" => %{lat: 45.5152, lng: -122.6784},
    "123 Main St" => %{lat: 40.7580, lng: -73.9855},
    "456 Oak Ave" => %{lat: 34.0195, lng: -118.4912},
    "789 Pine St" => %{lat: 41.8827, lng: -87.6233},
    "Central Park, NY" => %{lat: 40.7829, lng: -73.9654},
    "Golden Gate Park, SF" => %{lat: 37.7694, lng: -122.4862}
  }

  @impl true
  def geocode(address) when is_binary(address) do
    # Normalize the address for case-insensitive matching
    normalized = String.trim(address)

    case Map.get(@known_locations, normalized) do
      nil ->
        # For unknown addresses in tests, generate a predictable coordinate
        # based on the hash of the address
        hash = :erlang.phash2(normalized, 1000)
        lat = 30.0 + hash / 100.0
        lng = -90.0 - hash / 100.0
        {:ok, %{lat: lat, lng: lng}}

      coordinates ->
        {:ok, coordinates}
    end
  end

  @impl true
  def reverse_geocode(lat, lng) when is_number(lat) and is_number(lng) do
    # Find the closest known location
    closest =
      @known_locations
      |> Enum.min_by(fn {_address, %{lat: loc_lat, lng: loc_lng}} ->
        :math.sqrt(:math.pow(lat - loc_lat, 2) + :math.pow(lng - loc_lng, 2))
      end)

    case closest do
      {address, _} -> {:ok, address}
      _ -> {:ok, "#{lat}, #{lng}"}
    end
  end
end
