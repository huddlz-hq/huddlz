defmodule Huddlz.Test.MoxHelpers do
  @moduledoc """
  Thin helpers for stubbing `Huddlz.MockPlaces` and `Huddlz.MockGeocoding`
  from tests. Each helper takes data (a map) and wires the corresponding
  `Mox.stub/3`; unknown keys fall through to the existing `PlacesStub` /
  `GeocodingStub` defaults (empty list or `{:error, :not_found}`).

  Canonical Places fixtures (see `known_places/0`) keep the literal place
  shape in one spot so changes to the `Huddlz.Places` contract only need
  to be made here.
  """

  import Mox

  @known_places %{
    austin: %{
      place_id: "p1",
      display_text: "Austin, TX, USA",
      main_text: "Austin",
      secondary_text: "TX, USA"
    },
    saint_augustine: %{
      place_id: "p2",
      display_text: "Saint Augustine, FL, USA",
      main_text: "Saint Augustine",
      secondary_text: "FL, USA"
    }
  }

  @known_coords %{
    "p1" => %{latitude: 30.27, longitude: -97.74},
    "p2" => %{latitude: 29.89, longitude: -81.31}
  }

  @doc """
  Canonical Places fixtures keyed by atom. Extend as tests need new cities.
  """
  def known_places, do: @known_places

  @doc """
  Coordinates matched to known `place_id`s. Convenience default for
  `stub_place_details/1`.
  """
  def known_coords, do: @known_coords

  @doc """
  Stub `Huddlz.MockPlaces.autocomplete/3` with a map of query-prefix to a
  list of place entries. Entries may be atoms referring to `known_places/0`
  or full maps matching the `Huddlz.Places` contract. Unmatched queries
  return `{:ok, []}`.

      stub_places_autocomplete(%{"aus" => [:austin]})
      stub_places_autocomplete(%{"saint" => [:saint_augustine]})
  """
  def stub_places_autocomplete(results_by_query) when is_map(results_by_query) do
    normalized =
      Map.new(results_by_query, fn {query, entries} ->
        {query, Enum.map(entries, &resolve_place/1)}
      end)

    stub(Huddlz.MockPlaces, :autocomplete, fn query, _token, _opts ->
      {:ok, Map.get(normalized, query, [])}
    end)
  end

  @doc """
  Stub `Huddlz.MockPlaces.autocomplete/3` to always return the same error.
  Useful for `{:error, {:request_failed, :timeout}}` scenarios.

      stub_places_autocomplete_error({:request_failed, :timeout})
  """
  def stub_places_autocomplete_error(reason) do
    stub(Huddlz.MockPlaces, :autocomplete, fn _, _token, _opts -> {:error, reason} end)
  end

  @doc """
  Stub `Huddlz.MockPlaces.place_details/2`. Accepts either a map of
  `place_id => coords` or `:defaults` to use `known_coords/0`. Unknown
  place ids fall through to `{:error, :not_found}`.

      stub_place_details(:defaults)
      stub_place_details(%{"p1" => %{latitude: 30.27, longitude: -97.74}})
  """
  def stub_place_details(:defaults), do: stub_place_details(@known_coords)

  def stub_place_details(coords_by_place_id) when is_map(coords_by_place_id) do
    stub(Huddlz.MockPlaces, :place_details, fn place_id, _token ->
      case Map.get(coords_by_place_id, place_id) do
        nil -> {:error, :not_found}
        coords -> {:ok, coords}
      end
    end)
  end

  @doc """
  Stub `Huddlz.MockPlaces.place_details/2` to always return the same error.
  """
  def stub_place_details_error(reason) do
    stub(Huddlz.MockPlaces, :place_details, fn _place_id, _token -> {:error, reason} end)
  end

  @doc """
  Stub `Huddlz.MockGeocoding.geocode/1`. Accepts:

    * a single `%{latitude: _, longitude: _}` map — return it for every address
    * a map of `address => coords` — per-address responses, unknown → `{:error, :not_found}`
  """
  def stub_geocode(%{latitude: _, longitude: _} = coords) do
    stub(Huddlz.MockGeocoding, :geocode, fn _address -> {:ok, coords} end)
  end

  def stub_geocode(coords_by_address) when is_map(coords_by_address) do
    stub(Huddlz.MockGeocoding, :geocode, fn address ->
      case Map.get(coords_by_address, address) do
        nil -> {:error, :not_found}
        coords -> {:ok, coords}
      end
    end)
  end

  defp resolve_place(key) when is_atom(key), do: Map.fetch!(@known_places, key)
  defp resolve_place(%{} = place), do: place
end
