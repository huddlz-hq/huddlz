defmodule Huddlz.Communities.Huddl.Changes.CancelRsvp do
  @moduledoc """
  Handles RSVP cancellation: destroys the attendee record if one exists.
  The rsvp_count is computed as an aggregate, so no manual counter management is needed.
  """
  use Ash.Resource.Change

  require Ash.Query

  def change(changeset, _opts, %{actor: %{id: user_id}}) when not is_nil(user_id) do
    huddl_id = changeset.data.id

    existing =
      Huddlz.Communities.HuddlAttendee
      |> Ash.Query.for_read(:check_rsvp, %{huddl_id: huddl_id}, actor: %{id: user_id})
      |> Ash.read_one(authorize?: false)

    case existing do
      {:ok, nil} ->
        changeset

      {:ok, attendee} ->
        Ash.destroy!(attendee, authorize?: false)
        Ash.Changeset.put_context(changeset, :rsvp_cancelled, true)

      {:error, error} ->
        Ash.Changeset.add_error(changeset, error)
    end
  end

  def change(changeset, _opts, _context) do
    Ash.Changeset.add_error(changeset, "An actor is required to cancel an RSVP")
  end
end
