defmodule Huddlz.Communities.Huddl.Changes.DeriveTimeZoneFromVenue do
  @moduledoc """
  Uses the selected saved venue's Location time zone for physical and hybrid huddlz.

  Virtual huddlz retain their organizer-selected Huddl time zone. Venue moves
  during editing are handled separately because they must preserve wall-clock
  scheduling intent.
  """

  use Ash.Resource.Change

  @physical_types [:in_person, :hybrid]

  @impl true
  def change(changeset, _opts, context) do
    event_type = Ash.Changeset.get_attribute(changeset, :event_type)
    location_id = Ash.Changeset.get_attribute(changeset, :group_location_id)

    derive_from_location(changeset, event_type, location_id, context)
  end

  defp derive_from_location(changeset, event_type, location_id, context)
       when event_type in @physical_types and not is_nil(location_id) do
    case Huddlz.Communities.get_group_location(location_id, scope: context) do
      {:ok, location} when not is_nil(location) ->
        Ash.Changeset.force_change_attribute(changeset, :time_zone, location.time_zone)

      {:error, _reason} ->
        venue_not_available(changeset)

      {:ok, nil} ->
        venue_not_available(changeset)
    end
  end

  defp derive_from_location(changeset, _event_type, _location_id, _context), do: changeset

  defp venue_not_available(changeset) do
    Ash.Changeset.add_error(changeset,
      field: :group_location_id,
      message: "selected venue is not available"
    )
  end
end
