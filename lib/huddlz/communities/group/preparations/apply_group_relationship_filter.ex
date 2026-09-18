defmodule Huddlz.Communities.Group.Preparations.ApplyGroupRelationshipFilter do
  @moduledoc """
  Filters a Group read down to the actor's relationship with the result rows.

  Reads the `:relationship` argument (one of `:all`, `:hosting`, `:joined`):

    * `:hosting` — the actor owns the group.
    * `:joined`  — the actor is a member but not the owner.
    * `:all`     — either of the above.
    * `:dropped_in` — public groups the actor has not joined, where they
      hold an RSVP on a published or completed huddl, or a waitlist spot on
      a huddl that has not ended yet, and have not dismissed or closed the
      reminder (see `Huddlz.Communities.DropInReminder`). Never part of
      `:all`.

  Sorting is delegated to `ApplyTrigramSearch` (alphabetical by `name` when
  no `:search` arg is present), so the SQL ordering matches the other group
  listings.
  """

  use Ash.Resource.Preparation

  require Ash.Query

  @impl true
  def prepare(query, _opts, context) do
    actor_id = context.actor && context.actor.id

    if is_nil(actor_id) do
      Ash.Query.filter(query, false)
    else
      relationship = Ash.Query.get_argument(query, :relationship) || :all
      apply_filter(query, relationship, actor_id)
    end
  end

  defp apply_filter(query, :hosting, actor_id),
    do: Ash.Query.filter(query, owner_id == ^actor_id)

  defp apply_filter(query, :joined, actor_id) do
    Ash.Query.filter(
      query,
      owner_id != ^actor_id and
        exists(group_members, user_id == ^actor_id)
    )
  end

  defp apply_filter(query, :dropped_in, actor_id) do
    query
    |> public_and_not_joined(actor_id)
    |> reminder_still_open(actor_id)
    |> holding_a_spot(actor_id)
  end

  defp apply_filter(query, :all, actor_id) do
    Ash.Query.filter(
      query,
      owner_id == ^actor_id or
        exists(group_members, user_id == ^actor_id)
    )
  end

  defp public_and_not_joined(query, actor_id) do
    Ash.Query.filter(
      query,
      is_public == true and owner_id != ^actor_id and
        not exists(group_members, user_id == ^actor_id)
    )
  end

  # "Not now", leaving and being removed each end the reminder for good.
  defp reminder_still_open(query, actor_id) do
    Ash.Query.filter(
      query,
      not exists(
        drop_in_reminders,
        user_id == ^actor_id and suppressed?
      )
    )
  end

  # An RSVP counts on a published or completed huddl. A waitlist spot counts
  # only while the huddl has not ended: once it is over, that spot never got
  # in. The end time decides, not the lifecycle state, because a huddl stays
  # published until the completion job records it. `HuddlAttendee`'s
  # `:drop_in_spots` read states the same rule from the spot's side.
  defp holding_a_spot(query, actor_id) do
    Ash.Query.filter(
      query,
      exists(
        huddlz,
        is_private == false and
          ((lifecycle_state in [:published, :completed] and
              exists(attendees, user_id == ^actor_id and is_nil(waitlisted_at))) or
             (lifecycle_state == :published and ends_at > now() and
                exists(attendees, user_id == ^actor_id)))
      )
    )
  end
end
