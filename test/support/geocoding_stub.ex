defmodule Huddlz.GeocodingStub do
  @moduledoc """
  Default stub implementation for geocoding in tests.
  Returns {:error, :not_found} for all calls (no coordinates set).
  Use Mox.expect/3 or Mox.stub/3 in individual tests to override.
  """
  @behaviour Huddlz.Geocoding

  @impl true
  def geocode(_address), do: {:error, :not_found}
end
