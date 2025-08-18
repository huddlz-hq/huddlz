defmodule Huddlz.Geocoding.Behaviour do
  @moduledoc """
  Behavior for geocoding services to convert addresses to coordinates and vice versa.
  """

  @callback geocode(String.t()) :: {:ok, %{lat: float(), lng: float()}} | {:error, term()}
  @callback reverse_geocode(float(), float()) :: {:ok, String.t()} | {:error, term()}
end