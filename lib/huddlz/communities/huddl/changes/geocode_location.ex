defmodule Huddlz.Communities.Huddl.Changes.GeocodeLocation do
  @moduledoc """
  Geocodes the physical_location to latitude/longitude coordinates on create/update.
  Only runs when physical_location is changing. On failure, sets lat/lng to nil.
  """
  use Ash.Resource.Change

  def change(changeset, _opts, _context) do
    Huddlz.Geocoding.Change.geocode_if_changed(changeset, :physical_location)
  end
end
