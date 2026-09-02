defmodule Huddlz.GeocodingStub do
  @moduledoc """
  Default stub implementation for geocoding in tests.

  Returns Saint Augustine coordinates for ordinary fixtures so required group
  locations are resolved by default.

  Tests that need real coordinates override via `Mox.stub/3` or the
  `stub_geocode/1` helper in `Huddlz.Test.MoxHelpers`.
  """
  @behaviour Huddlz.Geocoding

  @impl true
  def geocode(_address), do: {:ok, %{latitude: 29.9012, longitude: -81.3124}}
end
