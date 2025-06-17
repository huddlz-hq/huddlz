defmodule Huddlz.Geocoding.Mock do
  @moduledoc """
  Mock geocoding service for tests to avoid HTTP requests.
  """

  @behaviour Huddlz.Geocoding.Behaviour

  @impl true
  def geocode(address) when is_binary(address) do
    # Return predictable coordinates based on the address
    case address do
      "123 Main St, Anytown, USA" ->
        {:ok, %{lat: 40.7128, lng: -74.0060}}

      "456 Oak Ave, Somewhere, USA" ->
        {:ok, %{lat: 34.0522, lng: -118.2437}}

      "New York, NY" ->
        {:ok, %{lat: 40.7128, lng: -74.0060}}

      "Los Angeles, CA" ->
        {:ok, %{lat: 34.0522, lng: -118.2437}}

      "Chicago, IL" ->
        {:ok, %{lat: 41.8781, lng: -87.6298}}

      "10001" ->
        {:ok, %{lat: 40.7507, lng: -73.9970}}

      _ ->
        # For any other address, return a default location
        {:ok, %{lat: 40.7128, lng: -74.0060}}
    end
  end

  @impl true
  def geocode_to_point(address) when is_binary(address) do
    case geocode(address) do
      {:ok, %{lat: lat, lng: lng}} ->
        {:ok, %Geo.Point{coordinates: {lng, lat}, srid: 4326}}

      error ->
        error
    end
  end
end
