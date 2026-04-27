defmodule Huddlz.GeocodingStub do
  @moduledoc """
  Default stub implementation for geocoding in tests.

  Returns `{:error, :not_found}` for every address — matching the
  `Huddlz.Geocoding` typespec, which says successful coordinates are
  `%{latitude: float(), longitude: float()}` (not nilable).

  Tests that need real coordinates override via `Mox.stub/3` or the
  `stub_geocode/1` helper in `Huddlz.Test.MoxHelpers`.
  """
  @behaviour Huddlz.Geocoding

  @impl true
  def geocode(_address), do: {:error, :not_found}
end
