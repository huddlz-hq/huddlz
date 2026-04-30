defmodule Huddlz.Communities.Huddl.Changes.EnforceCapacityFloor do
  @moduledoc """
  Prevents organizers from reducing `max_attendees` below the current RSVP
  count. Locks the huddl row inside the action's transaction so the check is
  atomic with the update — no organizer/RSVP TOCTOU race.
  """
  use Ash.Resource.Change

  alias Huddlz.Communities.{Huddl, HuddlAttendee}

  require Ash.Query

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
    huddl_id = cs.data.id

    Huddl
    |> Ash.Query.filter(id == ^huddl_id)
    |> Ash.Query.lock("FOR UPDATE")
    |> Ash.read_one!(authorize?: false)

    rsvp_count =
      HuddlAttendee
      |> Ash.Query.for_read(:by_huddl, %{huddl_id: huddl_id})
      |> Ash.count!(authorize?: false)

    if new_max < rsvp_count do
      Ash.Changeset.add_error(cs,
        field: :max_attendees,
        message: "cannot be less than the current RSVP count"
      )
    else
      cs
    end
  end
end
