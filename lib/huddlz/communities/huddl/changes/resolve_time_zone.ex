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

  ## Create

  On create, Ash force-sets the resource's static `"Etc/UTC"` default into
  `changeset.attributes` *before* this change runs (see
  `Ash.Changeset.set_defaults/3`), so `Ash.Changeset.get_attribute/2` alone
  can't distinguish "defaulted" from "explicitly submitted". We check
  `changeset.defaults` (the list of attributes Ash defaulted rather than the
  caller setting) instead, which is only populated on the defaulting path.
  When defaulted, we resolve via geocoding with the full fallback chain
  above; when explicitly submitted, we leave it untouched.

  ## Update

  `changeset.defaults` is **not** useful here: `time_zone` only has a plain
  `default`, not an `update_default`, so Ash never force-sets it (and never
  populates `changeset.defaults` for it) on update — the check above would
  always read as "not defaulted", silently never re-deriving. Instead:

    * if the organizer explicitly submitted `time_zone` this call
      (`changing_attribute?(changeset, :time_zone)`), keep it — nothing else
      writes into `:time_zone`'s changes without an `update_default`, so this
      reliably means "the caller set it this call" on update (unlike create,
      where the static default also lands in `.attributes`);
    * else, if the huddl's own coordinates actually changed this call
      (`latitude`/`longitude` changing — e.g. the organizer edited the
      address to a new one, or `DefaultLocationFromGroup` just inherited new
      group coordinates), re-derive from a fresh geocode lookup only (no
      fallback chain — an update shouldn't overwrite a previously-resolved
      zone with `"Etc/UTC"` just because the new address didn't geocode; it
      simply leaves `time_zone` as persisted in that case);
    * else, leave `time_zone` exactly as persisted — an ordinary update that
      touches neither location nor `time_zone` is a no-op here.
  """
  use Ash.Resource.Change

  alias Huddlz.Communities.Group
  alias Huddlz.Geocoding.TimeZoneLookup

  @impl true
  def change(changeset, _opts, _context) do
    case changeset.action_type do
      :create -> handle_create(changeset)
      :update -> handle_update(changeset)
      _ -> changeset
    end
  end

  defp handle_create(changeset) do
    if :time_zone in changeset.defaults do
      force_set(changeset, resolve_with_fallback(changeset))
    else
      changeset
    end
  end

  defp handle_update(changeset) do
    cond do
      Ash.Changeset.changing_attribute?(changeset, :time_zone) ->
        changeset

      location_changed?(changeset) ->
        case geocode(changeset) do
          {:ok, time_zone} -> force_set(changeset, time_zone)
          :error -> changeset
        end

      true ->
        changeset
    end
  end

  defp location_changed?(changeset) do
    Ash.Changeset.changing_attribute?(changeset, :latitude) or
      Ash.Changeset.changing_attribute?(changeset, :longitude)
  end

  defp force_set(changeset, time_zone) do
    Ash.Changeset.force_change_attribute(changeset, :time_zone, time_zone)
  end

  defp resolve_with_fallback(changeset) do
    case geocode(changeset) do
      {:ok, time_zone} -> time_zone
      :error -> fallback(changeset)
    end
  end

  defp geocode(changeset) do
    lat = Ash.Changeset.get_attribute(changeset, :latitude)
    lng = Ash.Changeset.get_attribute(changeset, :longitude)

    with true <- is_number(lat) and is_number(lng),
         {:ok, time_zone} <- TimeZoneLookup.from_coordinates(lat, lng) do
      {:ok, time_zone}
    else
      _ -> :error
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
