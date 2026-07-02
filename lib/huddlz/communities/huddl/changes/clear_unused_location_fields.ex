defmodule Huddlz.Communities.Huddl.Changes.ClearUnusedLocationFields do
  @moduledoc """
  Clears the location field that doesn't apply to the huddl's event type:
  virtual huddlz carry no physical_location, in-person huddlz carry no
  virtual_link. Hybrid huddlz keep both.

  Only acts on create or when event_type is being set — an unrelated update
  (e.g. a title edit) must not touch stored location data, re-trigger
  geocoding, or notify attendees of a location change.

  Runs before geocoding so a cleared physical_location is never geocoded.
  """
  use Ash.Resource.Change

  def change(changeset, _opts, _context) do
    if changeset.action_type == :create or
         Ash.Changeset.changing_attribute?(changeset, :event_type) do
      clear_unused_field(changeset)
    else
      changeset
    end
  end

  defp clear_unused_field(changeset) do
    case Ash.Changeset.get_attribute(changeset, :event_type) do
      :virtual -> Ash.Changeset.force_change_attribute(changeset, :physical_location, nil)
      :in_person -> Ash.Changeset.force_change_attribute(changeset, :virtual_link, nil)
      _ -> changeset
    end
  end
end
