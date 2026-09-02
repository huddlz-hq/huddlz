defmodule Huddlz.Communities.Group.Changes.ResolveTimeZone do
  @moduledoc """
  Derives a Group's canonical time zone from its selected coordinates.

  New Groups and location changes require coordinates and a resolvable zone.
  Existing Groups whose location is unchanged retain their stored value so
  legacy rows without coordinates can still be edited safely.
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, &derive_time_zone/1)
  end

  defp derive_time_zone(changeset) do
    latitude = Ash.Changeset.get_attribute(changeset, :latitude)
    longitude = Ash.Changeset.get_attribute(changeset, :longitude)

    derive_time_zone(changeset, latitude, longitude)
  end

  defp derive_time_zone(changeset, latitude, longitude)
       when is_number(latitude) and is_number(longitude) do
    case Huddlz.LocationTimeZone.resolve(latitude, longitude) do
      {:ok, time_zone} ->
        Ash.Changeset.force_change_attribute(changeset, :time_zone, time_zone)

      {:error, _reason} ->
        Ash.Changeset.add_error(changeset,
          field: :location,
          message: "time zone could not be resolved for this location"
        )
    end
  end

  defp derive_time_zone(changeset, _latitude, _longitude) do
    if location_resolution_required?(changeset) do
      Ash.Changeset.add_error(changeset,
        field: :location,
        message: "time zone could not be resolved for this location"
      )
    else
      changeset
    end
  end

  defp location_resolution_required?(%{action_type: :create}), do: true

  defp location_resolution_required?(changeset) do
    Ash.Changeset.changing_attribute?(changeset, :location)
  end
end
