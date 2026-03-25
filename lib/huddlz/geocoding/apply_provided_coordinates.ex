defmodule Huddlz.Geocoding.ApplyProvidedCoordinates do
  @moduledoc """
  Applies pre-existing coordinates from the provided_latitude/provided_longitude arguments.
  Runs before GeocodeLocation so that geocoding is skipped when coordinates are already set.
  """
  use Ash.Resource.Change

  def change(changeset, _opts, _context) do
    lat = Ash.Changeset.get_argument(changeset, :provided_latitude)
    lng = Ash.Changeset.get_argument(changeset, :provided_longitude)

    if is_number(lat) and is_number(lng) do
      changeset
      |> Ash.Changeset.force_change_attribute(:latitude, lat)
      |> Ash.Changeset.force_change_attribute(:longitude, lng)
    else
      changeset
    end
  end
end
