defmodule Huddlz.Types.Geometry do
  @moduledoc """
  Custom Ash type for PostGIS geometry data.
  Handles Point geometries for storing coordinates.
  """
  use Ash.Type

  @impl true
  def storage_type(_), do: :geometry

  @impl true
  def cast_input(nil, _), do: {:ok, nil}
  
  def cast_input(%Geo.Point{} = point, _) do
    {:ok, point}
  end
  
  def cast_input(%{"lat" => lat, "lng" => lng}, _) when is_number(lat) and is_number(lng) do
    {:ok, %Geo.Point{coordinates: {lng, lat}, srid: 4326}}
  end
  
  def cast_input(%{lat: lat, lng: lng}, _) when is_number(lat) and is_number(lng) do
    {:ok, %Geo.Point{coordinates: {lng, lat}, srid: 4326}}
  end
  
  def cast_input(_, _), do: :error

  @impl true
  def cast_stored(nil, _), do: {:ok, nil}
  
  def cast_stored(%Geo.Point{} = point, _) do
    {:ok, point}
  end
  
  def cast_stored(_, _), do: :error

  @impl true
  def dump_to_native(nil, _), do: {:ok, nil}
  
  def dump_to_native(%Geo.Point{} = point, _) do
    {:ok, point}
  end
  
  def dump_to_native(_, _), do: :error
end