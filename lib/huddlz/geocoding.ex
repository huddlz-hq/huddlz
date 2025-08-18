defmodule Huddlz.Geocoding do
  @moduledoc """
  Main geocoding module that delegates to the configured geocoding service.
  The service can be configured at compile time via config files.
  """

  @service Application.compile_env(:huddlz, :geocoding_service, Huddlz.Geocoding.GoogleMaps)

  @doc """
  Geocodes an address string into coordinates.

  Returns `{:ok, %{lat: float, lng: float}}` on success,
  or `{:error, reason}` on failure.
  """
  def geocode(address) when is_binary(address) do
    @service.geocode(address)
  end

  @doc """
  Reverse geocodes coordinates into an address string.

  Returns `{:ok, address}` on success,
  or `{:error, reason}` on failure.
  """
  def reverse_geocode(lat, lng) when is_number(lat) and is_number(lng) do
    @service.reverse_geocode(lat, lng)
  end
end
