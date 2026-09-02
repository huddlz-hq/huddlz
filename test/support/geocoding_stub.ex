defmodule Huddlz.GeocodingStub do
  @moduledoc """
  Default stub implementation for geocoding in tests.

  Returns deterministic Eastern-zone coordinates so ordinary Group fixtures
  satisfy the location-derived time-zone invariant without network access.
  Tests of other coordinates or failure behavior override this with
  `Mox.stub/3` or the `stub_geocode/1` helper.
  """
  @behaviour Huddlz.Geocoding

  @impl true
  def geocode(_address), do: {:ok, %{latitude: 29.89, longitude: -81.31}}
end
