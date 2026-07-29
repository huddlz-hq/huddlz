defmodule Huddlz.Communities.Huddl.Changes.JoinWaitlist do
  @moduledoc """
  Adds the actor to the huddl's waitlist when the huddl is full.

  Like `Rsvp`, locks the huddl row inside the action's transaction so
  the capacity check that decides "you should join the waitlist instead"
  is consistent with concurrent RSVP attempts.
  """
  use Ash.Resource.Change

  alias Huddlz.Communities.Huddl
  alias Huddlz.Communities.Huddl.Changes.LockedHuddl
  alias Huddlz.Communities.HuddlAttendee

  def change(changeset, _opts, %{actor: %{id: user_id}}) when not is_nil(user_id) do
    Ash.Changeset.before_action(changeset, &queue_spot(&1, user_id))
  end

  def change(changeset, _opts, _context) do
    Ash.Changeset.add_error(changeset, "An actor is required to join the waitlist")
  end

  defp queue_spot(cs, user_id) do
    case LockedHuddl.fetch(cs.data.id, :at_capacity) do
      {:ok, %Huddl{} = huddl} -> queue_spot(cs, huddl, user_id)
      error -> LockedHuddl.add_read_error(cs, error)
    end
  end

  defp queue_spot(cs, huddl, user_id) do
    cond do
      is_nil(huddl.max_attendees) ->
        Ash.Changeset.add_error(cs, "This huddl has no capacity limit; RSVP directly")

      not huddl.at_capacity ->
        Ash.Changeset.add_error(cs, "This huddl still has open spots; RSVP directly")

      true ->
        case fetch_existing(huddl.id, user_id) do
          {:ok, nil} -> create_waitlist_entry(cs, huddl.id, user_id)
          {:ok, _existing} -> cs
          {:error, error} -> Ash.Changeset.add_error(cs, error)
        end
    end
  end

  defp create_waitlist_entry(cs, huddl_id, user_id) do
    HuddlAttendee
    |> Ash.Changeset.for_create(:join_waitlist, %{huddl_id: huddl_id, user_id: user_id})
    |> Ash.create!(authorize?: false)

    cs
  end

  defp fetch_existing(huddl_id, user_id) do
    HuddlAttendee
    |> Ash.Query.for_read(:check_rsvp, %{huddl_id: huddl_id}, actor: %{id: user_id})
    |> Ash.read_one(authorize?: false)
  end
end
