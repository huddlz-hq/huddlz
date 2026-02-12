defmodule Huddlz.Communities.Group.Changes.GeocodeLocation do
  @moduledoc """
  Geocodes the group location to latitude/longitude coordinates on create/update.
  Only runs when location is changing. On failure, sets lat/lng to nil.
  """
  use Ash.Resource.Change

  def change(changeset, _opts, _context) do
    Huddlz.Geocoding.Change.geocode_if_changed(changeset, :location)
  end
end
