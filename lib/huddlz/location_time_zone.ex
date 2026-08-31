defmodule Huddlz.LocationTimeZone do
  @moduledoc """
  Resolves a canonical IANA Location time zone from selected coordinates.

  Resolution happens when a location is selected or saved so rendering never
  depends on an external lookup.
  """

  @adapter Application.compile_env!(:huddlz, [:location_time_zone, :adapter])

  @callback resolve(latitude :: float(), longitude :: float()) ::
              {:ok, String.t()} | {:error, term()}

  def resolve(latitude, longitude) when is_number(latitude) and is_number(longitude) do
    case @adapter.resolve(latitude, longitude) do
      {:ok, time_zone} -> canonical_result(time_zone)
      {:error, _reason} = error -> error
    end
  end

  def resolve(_, _), do: {:error, :invalid_coordinates}

  defp canonical_result(time_zone) do
    if Huddlz.TimeZone.canonical?(time_zone) do
      {:ok, time_zone}
    else
      {:error, :invalid_time_zone}
    end
  end
end
