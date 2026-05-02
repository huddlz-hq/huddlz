defmodule Huddlz.Communities.Huddl.Changes.JoinWaitlist do
  @moduledoc """
  Adds the actor to the huddl's waitlist when the huddl is full.

  Like `Rsvp`, locks the huddl row inside the action's transaction so
  the capacity check that decides "you should join the waitlist instead"
  is consistent with concurrent RSVP attempts.
  """
  use Ash.Resource.Change

  alias Huddlz.Communities.{Huddl, HuddlAttendee}

  require Ash.Query

  def change(changeset, _opts, %{actor: %{id: user_id}}) when not is_nil(user_id) do
    Ash.Changeset.before_action(changeset, &queue_spot(&1, user_id))
  end

  def change(changeset, _opts, _context) do
    Ash.Changeset.add_error(changeset, "An actor is required to join the waitlist")
  end

  defp queue_spot(cs, user_id) do
    huddl = lock_huddl!(cs.data.id)

    cond do
      is_nil(huddl.max_attendees) ->
        Ash.Changeset.add_error(cs, "This huddl has no capacity limit; RSVP directly")

      not at_capacity?(huddl) ->
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

  defp lock_huddl!(huddl_id) do
    Huddl
    |> Ash.Query.filter(id == ^huddl_id)
    |> Ash.Query.lock("FOR UPDATE")
    |> Ash.Query.load(:rsvp_count)
    |> Ash.read_one!(authorize?: false)
  end

  defp fetch_existing(huddl_id, user_id) do
    HuddlAttendee
    |> Ash.Query.for_read(:check_rsvp, %{huddl_id: huddl_id}, actor: %{id: user_id})
    |> Ash.read_one(authorize?: false)
  end

  defp at_capacity?(%{max_attendees: nil}), do: false
  defp at_capacity?(%{max_attendees: max, rsvp_count: count}), do: count >= max
end
