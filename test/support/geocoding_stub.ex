defmodule Huddlz.GeocodingStub do
  @moduledoc """
  Default stub implementation for geocoding in tests.
  Returns {:error, :no_api_key} for all calls (no coordinates set).
  Use Mox.expect/3 or Mox.stub/3 in individual tests to override.
  """
  @behaviour Huddlz.Geocoding

  @impl true
  def geocode(_address), do: {:error, :no_api_key}
end
