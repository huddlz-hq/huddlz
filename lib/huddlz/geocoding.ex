defmodule Huddlz.Geocoding do
  @moduledoc """
  Geocoding service interface.
  Delegates to the configured implementation (real or mock).
  """

  @doc """
  Get the configured geocoding implementation module.
  """
  def impl do
    Application.get_env(:huddlz, :geocoding_module, Huddlz.Geocoding.Real)
  end

  @doc """
  Geocode an address to coordinates.
  """
  def geocode(address) do
    impl().geocode(address)
  end

  @doc """
  Geocode an address to a PostGIS point.
  """
  def geocode_to_point(address) do
    impl().geocode_to_point(address)
  end
end
