defmodule Huddlz.Communities.Group.Changes.SetTimeZoneFromLocation do
  @moduledoc """
  Geo-derives `time_zone` from the group's (already-geocoded) latitude/longitude
  when the organizer didn't explicitly submit a `time_zone`. Runs after
  `GeocodeChange` so coordinates reflect their final resolved value.

  ## Create

  On create, Ash force-sets the resource's static `"Etc/UTC"` default into
  `changeset.attributes` *before* this change runs (see
  `Ash.Changeset.set_defaults/3`), so `Ash.Changeset.get_attribute/2` alone
  can't distinguish "defaulted" from "explicitly submitted". We check
  `changeset.defaults` (the list of attributes Ash defaulted rather than the
  caller setting) instead, which is only populated on the defaulting path:
  derive from the geocoded location when defaulted, otherwise keep the
  organizer's explicit value untouched.

  ## Update

  `changeset.defaults` is **not** useful here: `time_zone` only has a plain
  `default`, not an `update_default`, so Ash never force-sets it (and never
  populates `changeset.defaults` for it) on update — checking it the same
  way as create would always read "not defaulted" and silently never
  re-derive. Instead:

    * if the organizer explicitly submitted `time_zone` this call
      (`changing_attribute?(changeset, :time_zone)`), keep it — nothing else
      writes into `:time_zone`'s changes without an `update_default`, so this
      reliably means "the caller set it this call" on update (unlike create,
      where the static default also lands in `.attributes`);
    * else, if the group's own coordinates actually changed this call
      (`latitude`/`longitude` changing — the organizer edited the location to
      a new one), re-derive from a fresh geocode lookup — this makes the
      change a no-op on ordinary updates that don't touch the location, and
      re-derives on ones that do;
    * else, leave `time_zone` exactly as persisted.
  """
  use Ash.Resource.Change

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
      derive(changeset)
    else
      changeset
    end
  end

  defp handle_update(changeset) do
    cond do
      Ash.Changeset.changing_attribute?(changeset, :time_zone) ->
        changeset

      location_changed?(changeset) ->
        derive(changeset)

      true ->
        changeset
    end
  end

  defp location_changed?(changeset) do
    Ash.Changeset.changing_attribute?(changeset, :latitude) or
      Ash.Changeset.changing_attribute?(changeset, :longitude)
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
