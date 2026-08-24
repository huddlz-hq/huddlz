defmodule Huddlz.Communities.Group.Changes.SetTimeZoneFromLocation do
  @moduledoc """
  Geo-derives `time_zone` from the group's (already-geocoded) latitude/longitude
  when the organizer didn't explicitly submit a `time_zone`. Runs after
  `GeocodeChange` so coordinates reflect their final resolved value.

  Leaves `time_zone` untouched when the organizer explicitly set it — this
  makes the change a no-op on ordinary updates that don't touch the location,
  and preserves an explicit override on create.

  Note: on create, Ash force-sets the resource's static `"Etc/UTC"` default
  into `changeset.changes` *before* this change runs (see
  `Ash.Changeset.set_defaults/3`), so `Ash.Changeset.get_attribute/2` alone
  can't distinguish "defaulted" from "explicitly submitted". We additionally
  check `changeset.defaults` (the list of attributes Ash defaulted rather
  than the caller setting), which is only populated on the defaulting path.
  """
  use Ash.Resource.Change

  alias Huddlz.Geocoding.TimeZoneLookup

  @impl true
  def change(changeset, _opts, _context) do
    if explicitly_set?(changeset) do
      changeset
    else
      derive(changeset)
    end
  end

  defp explicitly_set?(changeset) do
    :time_zone not in changeset.defaults && !!Ash.Changeset.get_attribute(changeset, :time_zone)
  end

  defp derive(changeset) do
    lat = Ash.Changeset.get_attribute(changeset, :latitude)
    lng = Ash.Changeset.get_attribute(changeset, :longitude)

    case is_number(lat) and is_number(lng) and TimeZoneLookup.from_coordinates(lat, lng) do
      {:ok, time_zone} -> Ash.Changeset.force_change_attribute(changeset, :time_zone, time_zone)
      _ -> changeset
    end
  end
end
