defmodule Huddlz.Communities.Huddl.Changes.ResolveTimeZone do
  @moduledoc """
  Resolves `time_zone` when the organizer didn't explicitly pick one:
  geo-derives from the huddl's coordinates (its own, or inherited from the
  group for a virtual huddl — see `DefaultLocationFromGroup`) when present,
  else falls back to the `browser_time_zone` argument, else the parent
  group's `time_zone`, else `"Etc/UTC"`.

  Must run after `ClearUnusedLocationFields`, `ApplyProvidedCoordinates`,
  `GeocodeChange`, and `DefaultLocationFromGroup` so `latitude`/`longitude`
  reflect their final resolved values, and before `CalculateDateTimeFromInputs`
  / `FutureDateValidation` so wall-time conversion uses the right zone.

  Note: on create, Ash force-sets the resource's static `"Etc/UTC"` default
  into `changeset.attributes` *before* this change runs (see
  `Ash.Changeset.set_defaults/3`), so `Ash.Changeset.get_attribute/2` alone
  can't distinguish "defaulted" from "explicitly submitted". We additionally
  check `changeset.defaults` (the list of attributes Ash defaulted rather
  than the caller setting), which is only populated on the defaulting path.
  """
  use Ash.Resource.Change

  alias Huddlz.Communities.Group
  alias Huddlz.Geocoding.TimeZoneLookup

  @impl true
  def change(changeset, _opts, _context) do
    if :time_zone in changeset.defaults do
      resolve_and_set(changeset)
    else
      changeset
    end
  end

  defp resolve_and_set(changeset) do
    Ash.Changeset.force_change_attribute(changeset, :time_zone, resolve(changeset))
  end

  defp resolve(changeset) do
    lat = Ash.Changeset.get_attribute(changeset, :latitude)
    lng = Ash.Changeset.get_attribute(changeset, :longitude)

    with true <- is_number(lat) and is_number(lng),
         {:ok, time_zone} <- TimeZoneLookup.from_coordinates(lat, lng) do
      time_zone
    else
      _ -> fallback(changeset)
    end
  end

  defp fallback(changeset) do
    case Ash.Changeset.get_argument(changeset, :browser_time_zone) do
      time_zone when is_binary(time_zone) and time_zone != "" -> time_zone
      _ -> group_time_zone(changeset)
    end
  end

  defp group_time_zone(changeset) do
    case get_group(changeset) do
      %{time_zone: time_zone} when is_binary(time_zone) -> time_zone
      _ -> "Etc/UTC"
    end
  end

  defp get_group(changeset) do
    case changeset.context do
      %{group: group} when not is_nil(group) ->
        group

      _ ->
        group_id = Ash.Changeset.get_attribute(changeset, :group_id)

        case Ash.get(Group, group_id, authorize?: false) do
          {:ok, group} -> group
          _ -> nil
        end
    end
  end
end
