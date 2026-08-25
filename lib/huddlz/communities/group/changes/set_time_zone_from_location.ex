defmodule Huddlz.Communities.Group.Changes.SetTimeZoneFromLocation do
  @moduledoc """
  Geo-derives `time_zone` from the group's (already-geocoded) latitude/longitude
  when the organizer didn't explicitly submit a `time_zone`. Runs after
  `GeocodeChange` so coordinates reflect their final resolved value.

  ## Create

  `:time_zone` is *not* accepted by the `:create_group` action; the
  organizer's explicit pick arrives as the nullable `:time_zone_selection`
  argument instead. This is what makes "blank means auto-derive" work: the
  attribute carries a static `"Etc/UTC"` default that
  `Ash.Changeset.set_defaults/3` force-sets into `changeset.attributes`
  before a form ever renders, so an attribute-bound picker renders
  pre-selected on `"Etc/UTC"` and submits it back on every create — leaving
  nothing to distinguish "defaulted" from "explicitly picked". The argument
  has no default of its own, so a blank submission really is blank.

  So: a non-empty `:time_zone_selection` wins as-is; otherwise derive from
  the geocoded location (leaving the `"Etc/UTC"` default in place when the
  location didn't geocode).

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
    case Ash.Changeset.get_argument(changeset, :time_zone_selection) do
      selected when is_binary(selected) and selected != "" ->
        Ash.Changeset.force_change_attribute(changeset, :time_zone, selected)

      _ ->
        derive(changeset)
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
