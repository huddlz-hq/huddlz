defmodule Huddlz.Communities.Huddl.Changes.GeocodeLocation do
  @moduledoc """
  Geocodes the physical_location to coordinates when it changes.
  Only geocodes for in-person and hybrid events.
  """
  use Ash.Resource.Change

  alias Huddlz.Geocoding

  def change(changeset, _opts, _context) do
    event_type = Ash.Changeset.get_attribute(changeset, :event_type)

    # Only geocode for in-person and hybrid events
    if should_geocode?(event_type, changeset) do
      geocode_location(changeset)
    else
      changeset
    end
  end

  defp should_geocode?(event_type, changeset) do
    event_type in [:in_person, :hybrid] and
      Ash.Changeset.changing_attribute?(changeset, :physical_location)
  end

  defp geocode_location(changeset) do
    case Ash.Changeset.get_attribute(changeset, :physical_location) do
      nil ->
        # Clear coordinates if location is removed
        Ash.Changeset.change_attribute(changeset, :coordinates, nil)

      location ->
        apply_geocoding(changeset, location)
    end
  end

  defp apply_geocoding(changeset, location) do
    case Geocoding.geocode_to_point(location) do
      {:ok, point} ->
        Ash.Changeset.change_attribute(changeset, :coordinates, point)

      {:error, _reason} ->
        # If geocoding fails, continue without coordinates
        # Could add an error or warning here if desired
        changeset
    end
  end
end
