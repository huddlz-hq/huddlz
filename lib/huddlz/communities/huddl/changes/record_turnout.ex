defmodule Huddlz.Communities.Huddl.Changes.RecordTurnout do
  @moduledoc """
  Records turnout for an ended huddl: people in the room, people on the
  call, or both, depending on the huddl type. The counts are stamped with
  the time they were recorded and any earlier dismissal is cleared.

  See ADR 0003: turnout is a headcount, never per-person check-in.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    in_room = Ash.Changeset.get_argument(changeset, :in_room)
    on_call = Ash.Changeset.get_argument(changeset, :on_call)

    changeset
    |> validate(changeset.data.event_type, in_room, on_call)
    |> Ash.Changeset.force_change_attribute(:turnout_in_room, in_room)
    |> Ash.Changeset.force_change_attribute(:turnout_on_call, on_call)
    |> Ash.Changeset.force_change_attribute(:turnout_recorded_at, DateTime.utc_now())
    |> Ash.Changeset.force_change_attribute(:turnout_skipped_at, nil)
  end

  defp validate(changeset, :in_person, in_room, on_call) do
    changeset
    |> require(:in_room, in_room, "how many people were in the room")
    |> forbid(:on_call, on_call, "an in-person huddl has no call to count")
  end

  defp validate(changeset, :virtual, in_room, on_call) do
    changeset
    |> require(:on_call, on_call, "how many people were on the call")
    |> forbid(:in_room, in_room, "a virtual huddl has no room to count")
  end

  defp validate(changeset, :hybrid, in_room, on_call) do
    changeset
    |> require(:in_room, in_room, "how many people were in the room")
    |> require(:on_call, on_call, "how many people were on the call")
  end

  defp require(changeset, field, nil, message) do
    Ash.Changeset.add_error(changeset, field: field, message: "is required: #{message}")
  end

  defp require(changeset, _field, _value, _message), do: changeset

  defp forbid(changeset, _field, nil, _message), do: changeset

  defp forbid(changeset, field, _value, message) do
    Ash.Changeset.add_error(changeset, field: field, message: message)
  end
end
