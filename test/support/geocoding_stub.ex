defmodule Huddlz.GeocodingStub do
  @moduledoc """
  Default stub implementation for geocoding in tests.

  Returns `{:ok, %{latitude: nil, longitude: nil}}` for every address. This
  matches the end state of the production fallback (no coords set on the
  record) without firing the `Geocoding failed for ...` warning, which is
  log-spam in test runs that don't care about geocoding.

  Tests that need real coordinates should override via `Mox.stub/3` or the
  `stub_geocode/1` helper in `Huddlz.Test.MoxHelpers`.
  """
  @behaviour Huddlz.Geocoding

  @impl true
  def geocode(_address), do: {:ok, %{latitude: nil, longitude: nil}}
end
