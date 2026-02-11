defmodule Huddlz.Geocoding do
  @moduledoc """
  Geocoding behaviour and facade for converting addresses to coordinates.
  Delegates to the configured adapter (Google Maps in production, Mox in test).
  """

  @type coordinates :: %{latitude: float(), longitude: float()}

  @doc "Geocode an address string to latitude/longitude coordinates"
  @callback geocode(String.t()) :: {:ok, coordinates()} | {:error, term()}

  @adapter Application.compile_env(:huddlz, [:geocoding, :adapter], Huddlz.Geocoding.Google)

  @doc """
  Geocode an address to coordinates using the configured adapter.
  """
  def geocode(address), do: @adapter.geocode(address)

  @doc """
  Calculate the distance in miles between two coordinate pairs using the Haversine formula.
  """
  @spec distance_miles({float(), float()}, {float(), float()}) :: float()
  def distance_miles({lat1, lng1}, {lat2, lng2}) do
    earth_radius_miles = 3958.8

    dlat = deg_to_rad(lat2 - lat1)
    dlng = deg_to_rad(lng2 - lng1)

    a =
      :math.sin(dlat / 2) * :math.sin(dlat / 2) +
        :math.cos(deg_to_rad(lat1)) * :math.cos(deg_to_rad(lat2)) *
          :math.sin(dlng / 2) * :math.sin(dlng / 2)

    c = 2 * :math.atan2(:math.sqrt(a), :math.sqrt(1 - a))

    Float.round(earth_radius_miles * c, 1)
  end

  defp deg_to_rad(deg), do: deg * :math.pi() / 180
end
