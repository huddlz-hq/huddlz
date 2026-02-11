defmodule Huddlz.Communities.Group.Changes.GeocodeLocation do
  @moduledoc """
  Geocodes the group location to latitude/longitude coordinates on create/update.
  Only runs when location is changing. On failure, sets lat/lng to nil.
  """
  use Ash.Resource.Change

  def change(changeset, _opts, _context) do
    if Ash.Changeset.changing_attribute?(changeset, :location) do
      changeset
      |> Ash.Changeset.get_attribute(:location)
      |> geocode_and_apply(changeset)
    else
      changeset
    end
  end

  defp geocode_and_apply(nil, changeset) do
    set_coordinates(changeset, nil, nil)
  end

  defp geocode_and_apply(location, changeset) do
    case Huddlz.Geocoding.geocode(location) do
      {:ok, %{latitude: lat, longitude: lng}} -> set_coordinates(changeset, lat, lng)
      {:error, _reason} -> set_coordinates(changeset, nil, nil)
    end
  end

  defp set_coordinates(changeset, lat, lng) do
    changeset
    |> Ash.Changeset.force_change_attribute(:latitude, lat)
    |> Ash.Changeset.force_change_attribute(:longitude, lng)
  end
end
