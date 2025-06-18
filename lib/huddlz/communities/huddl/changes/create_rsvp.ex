defmodule Huddlz.Communities.Huddl.Changes.CreateRsvp do
  @moduledoc """
  Creates an RSVP for a user to a huddl and updates the RSVP count.
  """
  use Ash.Resource.Change

  def change(changeset, _opts, _context) do
    user_id = Ash.Changeset.get_argument(changeset, :user_id)
    huddl_id = changeset.data.id

    # Check if already RSVPed
    existing =
      Huddlz.Communities.HuddlAttendee
      |> Ash.Query.for_read(:check_rsvp, %{huddl_id: huddl_id, user_id: user_id})
      |> Ash.read_one(authorize?: false)

    case existing do
      {:ok, nil} ->
        # Create RSVP
        Huddlz.Communities.HuddlAttendee
        |> Ash.Changeset.for_create(:rsvp, %{huddl_id: huddl_id, user_id: user_id})
        |> Ash.create!(authorize?: false)

        # Increment count
        Ash.Changeset.change_attribute(changeset, :rsvp_count, changeset.data.rsvp_count + 1)

      {:ok, _} ->
        # Already RSVPed, no change needed
        changeset

      {:error, error} ->
        Ash.Changeset.add_error(changeset, error)
    end
  end
end
