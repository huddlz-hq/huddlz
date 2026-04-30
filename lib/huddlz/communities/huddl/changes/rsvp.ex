defmodule Huddlz.Communities.Huddl.Changes.Rsvp do
  @moduledoc """
  Handles RSVP logic: creates an attendee record if one doesn't already exist.
  The rsvp_count is computed as an aggregate, so no manual counter management is needed.

  Concurrency: locks the huddl row inside the action's transaction so that
  concurrent RSVPs serialize on capacity checks and cannot overbook.
  """
  use Ash.Resource.Change

  alias Huddlz.Communities.{Huddl, HuddlAttendee}

  require Ash.Query

  def change(changeset, _opts, %{actor: %{id: user_id}}) when not is_nil(user_id) do
    Ash.Changeset.before_action(changeset, &reserve_spot(&1, user_id))
  end

  def change(changeset, _opts, _context) do
    Ash.Changeset.add_error(changeset, "An actor is required to RSVP")
  end

  defp reserve_spot(cs, user_id) do
    huddl_id = cs.data.id
    huddl = lock_huddl!(huddl_id)

    case fetch_existing_rsvp(huddl_id, user_id) do
      {:ok, nil} -> claim_or_reject(cs, huddl, huddl_id, user_id)
      {:ok, _attendee} -> cs
      {:error, error} -> Ash.Changeset.add_error(cs, error)
    end
  end

  defp claim_or_reject(cs, huddl, huddl_id, user_id) do
    if at_capacity?(huddl, huddl_id) do
      Ash.Changeset.add_error(cs, "This huddl is full")
    else
      create_rsvp!(huddl_id, user_id)
      cs
    end
  end

  defp lock_huddl!(huddl_id) do
    Huddl
    |> Ash.Query.filter(id == ^huddl_id)
    |> Ash.Query.lock("FOR UPDATE")
    |> Ash.read_one!(authorize?: false)
  end

  defp fetch_existing_rsvp(huddl_id, user_id) do
    HuddlAttendee
    |> Ash.Query.for_read(:check_rsvp, %{huddl_id: huddl_id}, actor: %{id: user_id})
    |> Ash.read_one(authorize?: false)
  end

  defp at_capacity?(%{max_attendees: nil}, _huddl_id), do: false

  defp at_capacity?(%{max_attendees: max}, huddl_id) do
    HuddlAttendee
    |> Ash.Query.for_read(:by_huddl, %{huddl_id: huddl_id})
    |> Ash.count!(authorize?: false) >= max
  end

  defp create_rsvp!(huddl_id, user_id) do
    HuddlAttendee
    |> Ash.Changeset.for_create(:rsvp, %{huddl_id: huddl_id, user_id: user_id})
    |> Ash.create!(authorize?: false)
  end
end
