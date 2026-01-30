defmodule Huddlz.Geocoding do
  @moduledoc """
  Geocoding service for address autocomplete and place details.

  Delegates to the configured implementation (Google Places API by default).
  In tests, this can be swapped to a Mox mock via config.

  ## Configuration

  Configure the Google Maps API key in runtime.exs:

      config :huddlz, :google_maps, api_key: "your_api_key"

  For testing, configure the mock implementation in test.exs:

      config :huddlz, :geocoding_service, Huddlz.Geocoding.Mock

  ## Usage

      # Search for address suggestions
      {:ok, suggestions} = Huddlz.Geocoding.autocomplete("123 main st")

      # Get full address details
      {:ok, address} = Huddlz.Geocoding.place_details("ChIJ...")
  """

  @doc """
  Search for address suggestions based on a query string.

  ## Options

    * `:country` - Restrict results to a specific country (e.g., "us")

  ## Examples

      iex> Huddlz.Geocoding.autocomplete("123 main")
      {:ok, [%{place_id: "abc123", description: "123 Main St, City, ST"}]}

      iex> Huddlz.Geocoding.autocomplete("123 main", country: "us")
      {:ok, [%{place_id: "abc123", description: "123 Main St, City, ST, USA"}]}
  """
  def autocomplete(query, opts \\ []) do
    impl().autocomplete(query, opts)
  end

  @doc """
  Get detailed address information for a place_id.

  Returns full address data including coordinates and address components.

  ## Examples

      iex> Huddlz.Geocoding.place_details("ChIJ...")
      {:ok, %{
        formatted_address: "123 Main St, San Francisco, CA 94102, USA",
        latitude: 37.7749,
        longitude: -122.4194,
        city: "San Francisco",
        state: "CA",
        ...
      }}
  """
  def place_details(place_id) do
    impl().place_details(place_id)
  end

  defp impl do
    Application.get_env(:huddlz, :geocoding_service, Huddlz.Geocoding.Google)
  end
end
