defmodule Huddlz.Communities.Huddl.Changes.DeleteRsvp do
  @moduledoc """
  Deletes an RSVP for a user from a huddl and updates the RSVP count.
  """
  use Ash.Resource.Change

  def change(changeset, _opts, _context) do
    user_id = Ash.Changeset.get_argument(changeset, :user_id)
    huddl_id = changeset.data.id

    # Find the existing RSVP
    existing =
      Huddlz.Communities.HuddlAttendee
      |> Ash.Query.for_read(:check_rsvp, %{huddl_id: huddl_id, user_id: user_id})
      |> Ash.read_one(authorize?: false)

    case existing do
      {:ok, nil} ->
        # No RSVP to cancel, return unchanged
        changeset

      {:ok, attendee} ->
        # Delete the attendee record
        Ash.destroy!(attendee, authorize?: false)

        # Decrement count
        Ash.Changeset.change_attribute(
          changeset,
          :rsvp_count,
          max(changeset.data.rsvp_count - 1, 0)
        )

      {:error, error} ->
        Ash.Changeset.add_error(changeset, error)
    end
  end
end
