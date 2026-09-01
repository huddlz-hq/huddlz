defmodule Huddlz.Communities.GroupLocation.Changes.ResolveTimeZone do
  @moduledoc """
  Resolves a saved venue's canonical Location time zone from its coordinates.

  A canonical organizer choice is retained only when the coordinate provider
  cannot resolve the venue. A successful provider result is authoritative.
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    latitude = Ash.Changeset.get_attribute(changeset, :latitude)
    longitude = Ash.Changeset.get_attribute(changeset, :longitude)

    case Huddlz.LocationTimeZone.resolve(latitude, longitude) do
      {:ok, time_zone} ->
        Ash.Changeset.force_change_attribute(changeset, :time_zone, time_zone)

      {:error, _reason} ->
        retain_manual_time_zone(changeset)
    end
  end

  defp retain_manual_time_zone(changeset) do
    case Ash.Changeset.get_argument(changeset, :time_zone) do
      time_zone when is_binary(time_zone) ->
        Ash.Changeset.force_change_attribute(changeset, :time_zone, time_zone)

      _other ->
        changeset
    end
  end
end
