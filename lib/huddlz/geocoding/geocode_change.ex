defmodule Huddlz.Geocoding.GeocodeChange do
  @moduledoc """
  Parameterized Ash change that geocodes a location attribute to
  latitude/longitude on create/update.

  Pass the attribute to geocode via the `:field` option:

      change {Huddlz.Geocoding.GeocodeChange, field: :location}
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, opts, _context) do
    field = Keyword.fetch!(opts, :field)
    Huddlz.Geocoding.Change.geocode_if_changed(changeset, field)
  end
end
