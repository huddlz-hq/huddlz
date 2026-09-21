defmodule Huddlz.Communities.DropInHistory do
  @moduledoc """
  The RSVPs people made to a group's huddlz while they were not members of
  it, for the organizer overview's drop-in lines.

  RSVPs come from the rows still standing and from the group activity log,
  which remembers the ones since cancelled. Whether the person belonged at
  the time is `Huddlz.Communities.MembershipHistory`'s rule.

  The reads skip authorization; callers have already decided the actor may
  see the group's figures.
  """

  require Ash.Query

  alias Huddlz.Communities.{GroupActivity, HuddlAttendee, MembershipHistory, RsvpMoment}

  @opaque t :: %{group_id: String.t(), rsvps: map(), membership: MembershipHistory.t()}

  @doc "The RSVP and membership history of these people in the group."
  @spec load(String.t(), [String.t()]) :: t()
  def load(group_id, user_ids) do
    user_ids = Enum.uniq(user_ids)

    %{
      group_id: group_id,
      rsvps: rsvps(group_id, user_ids),
      membership: MembershipHistory.load([group_id], user_ids, nil)
    }
  end

  @doc """
  The latest RSVP the person made before the moment while not a member of
  the group, as `%{at: at, huddl_id: id}`, or nil. The huddl id is nil when
  the huddl is gone.
  """
  @spec latest_before(t(), String.t(), DateTime.t()) :: map() | nil
  def latest_before(%{group_id: group_id, rsvps: rsvps, membership: membership}, user_id, at) do
    rsvps
    |> Map.get(user_id, [])
    |> Enum.filter(fn rsvp ->
      DateTime.compare(rsvp.at, at) == :lt and
        not MembershipHistory.member_at?(membership, {user_id, group_id}, rsvp.at)
    end)
    |> Enum.max_by(&DateTime.to_unix(&1.at, :microsecond), fn -> nil end)
  end

  @doc "Whether the person belongs to the group now."
  @spec member_now?(t(), String.t()) :: boolean()
  def member_now?(%{group_id: group_id, membership: membership}, user_id),
    do: MembershipHistory.member_now?(membership, {user_id, group_id})

  defp rsvps(_group_id, []), do: %{}

  defp rsvps(group_id, user_ids) do
    activity =
      GroupActivity
      |> Ash.Query.filter(
        group_id == ^group_id and user_id in ^user_ids and kind in [:rsvped, :promoted]
      )
      |> Ash.Query.select([:user_id, :huddl_id, :kind, :occurred_at])
      |> Ash.read!(authorize?: false)

    promotions = RsvpMoment.promotions(activity)

    standing =
      HuddlAttendee
      |> Ash.Query.filter(
        huddl.group_id == ^group_id and user_id in ^user_ids and is_nil(waitlisted_at)
      )
      |> Ash.Query.select([:user_id, :huddl_id, :rsvped_at])
      |> Ash.read!(authorize?: false)
      |> Enum.map(fn row ->
        %{
          user_id: row.user_id,
          huddl_id: row.huddl_id,
          at: RsvpMoment.at(row, promotions)
        }
      end)

    logged =
      Enum.map(activity, &%{user_id: &1.user_id, huddl_id: &1.huddl_id, at: &1.occurred_at})

    Enum.group_by(standing ++ logged, & &1.user_id, &Map.take(&1, [:huddl_id, :at]))
  end
end
