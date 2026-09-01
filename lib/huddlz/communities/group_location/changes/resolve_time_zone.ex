defmodule Huddlz.Communities.GroupLocation.Changes.ResolveTimeZone do
  @moduledoc """
  Resolves a saved venue's canonical Location time zone from its coordinates.

  Resolution is authoritative. An address whose coordinates do not resolve
  cannot be saved with a manually supplied replacement zone.
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
        Ash.Changeset.add_error(changeset,
          field: :address,
          message: "time zone could not be resolved for this address"
        )
    end
  end
end
