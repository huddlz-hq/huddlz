defmodule Huddlz.Places.DevStub do
  @moduledoc """
  Development stub for Places autocomplete.

  Returns a fixed preset of locations regardless of the search query so the
  LocationAutocomplete component is fully usable without a Google API key.

  To enable, add to config/dev.exs:

      config :huddlz, :places, adapter: Huddlz.Places.DevStub
  """

  @behaviour Huddlz.Places

  @places [
    %{
      place_id: "dev_stub_sf",
      display_text: "San Francisco, CA, USA",
      main_text: "San Francisco",
      secondary_text: "CA, USA",
      latitude: 37.7749,
      longitude: -122.4194
    },
    %{
      place_id: "dev_stub_brooklyn",
      display_text: "Brooklyn, New York, NY, USA",
      main_text: "Brooklyn",
      secondary_text: "New York, NY, USA",
      latitude: 40.6782,
      longitude: -74.0060
    },
    %{
      place_id: "dev_stub_austin",
      display_text: "Austin, TX, USA",
      main_text: "Austin",
      secondary_text: "TX, USA",
      latitude: 30.2672,
      longitude: -97.7431
    },
    %{
      place_id: "dev_stub_chicago",
      display_text: "Chicago, IL, USA",
      main_text: "Chicago",
      secondary_text: "IL, USA",
      latitude: 41.8781,
      longitude: -87.6298
    },
    %{
      place_id: "dev_stub_portland",
      display_text: "Portland, OR, USA",
      main_text: "Portland",
      secondary_text: "OR, USA",
      latitude: 45.5051,
      longitude: -122.6750
    },
    %{
      place_id: "dev_stub_denver",
      display_text: "Denver, CO, USA",
      main_text: "Denver",
      secondary_text: "CO, USA",
      latitude: 39.7392,
      longitude: -104.9903
    },
    %{
      place_id: "dev_stub_nashville",
      display_text: "Nashville, TN, USA",
      main_text: "Nashville",
      secondary_text: "TN, USA",
      latitude: 36.1627,
      longitude: -86.7816
    }
  ]

  @suggestions Enum.map(
                 @places,
                 &Map.take(&1, [:place_id, :display_text, :main_text, :secondary_text])
               )

  @coordinates Map.new(@places, &{&1.place_id, %{latitude: &1.latitude, longitude: &1.longitude}})

  @impl true
  def autocomplete(_query, _session_token, _opts), do: {:ok, @suggestions}

  @impl true
  def place_details(place_id, _session_token) do
    case Map.fetch(@coordinates, place_id) do
      {:ok, coords} -> {:ok, coords}
      :error -> {:ok, %{latitude: 37.7749, longitude: -122.4194}}
    end
  end
end
