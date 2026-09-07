defmodule Huddlz.Communities.Huddl.Changes.EnforceCapacityFloor do
  @moduledoc """
  Prevents organizers from reducing `max_attendees` below the current RSVP
  count. Locks the huddl row inside the action's transaction so the check is
  atomic with the update — no organizer/RSVP TOCTOU race.
  """
  use Ash.Resource.Change

  alias Huddlz.Communities.Huddl
  alias Huddlz.Communities.Huddl.Changes.LockedHuddl

  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, fn cs ->
      with true <- Ash.Changeset.changing_attribute?(cs, :max_attendees),
           new_max when not is_nil(new_max) <-
             Ash.Changeset.get_attribute(cs, :max_attendees) do
        check_floor(cs, new_max)
      else
        _ -> cs
      end
    end)
  end

  defp check_floor(cs, new_max) do
    case LockedHuddl.fetch(cs.data.id, :rsvp_count) do
      {:ok, %Huddl{} = huddl} when new_max < huddl.rsvp_count ->
        add_capacity_error(cs)

      {:ok, %Huddl{}} ->
        cs

      error ->
        LockedHuddl.add_read_error(cs, error)
    end
  end

  defp add_capacity_error(cs) do
    Ash.Changeset.add_error(cs,
      field: :max_attendees,
      message: "cannot be less than the current RSVP count"
    )
  end
end
