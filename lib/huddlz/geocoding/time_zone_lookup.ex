defmodule Huddlz.Geocoding.TimeZoneLookup do
  @moduledoc """
  Offline lat/long -> IANA timezone lookup, backed by `tz_world`.
  """

  @spec from_coordinates(float(), float()) :: {:ok, String.t()} | :error
  def from_coordinates(lat, lng) when is_number(lat) and is_number(lng) do
    case TzWorld.timezone_at(%Geo.Point{coordinates: {lng, lat}}) do
      {:ok, time_zone} -> {:ok, time_zone}
      _ -> :error
    end
  end
end
