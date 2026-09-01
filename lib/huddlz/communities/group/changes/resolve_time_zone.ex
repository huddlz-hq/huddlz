defmodule Huddlz.Communities.Group.Changes.ResolveTimeZone do
  @moduledoc """
  Derives a new Group's canonical time zone from its selected coordinates.

  Existing internal callers that do not provide coordinates retain the
  attribute default. When a location picker supplies coordinates, resolution
  is authoritative and a failure rejects creation.
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
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

  defp derive_time_zone(changeset, _latitude, _longitude), do: changeset
end
