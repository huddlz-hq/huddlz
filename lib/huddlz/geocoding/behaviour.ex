defmodule Huddlz.Geocoding.Behaviour do
  @moduledoc """
  Behaviour for geocoding services.
  """

  @callback geocode(address :: String.t()) ::
              {:ok, %{lat: float(), lng: float()}} | {:error, atom()}

  @callback geocode_to_point(address :: String.t()) ::
              {:ok, Geo.Point.t()} | {:error, atom()}
end
