defmodule Huddlz.Communities.ActivityLog do
  @moduledoc """
  Appends to the group activity log as membership and attendance actions
  run. A notifier, like `MembershipEvents`: it sees each committed action
  and records what it meant in the group's terms.

  Membership: joining (directly, by an organizer, or by accepting an
  invitation) and leaving (or being removed). Attendance: an RSVP, a
  waitlist entry, a cancelled RSVP, a withdrawn waitlist entry, and a
  promotion from the waitlist. Owner rows from group creation and role
  changes are not activity.

  A failure to log is reported, never raised: the action that caused it
  has already committed.
  """

  @behaviour Ash.Notifier

  require Logger

  alias Huddlz.Communities.{GroupActivity, GroupMember, Huddl, HuddlAttendee}

  @impl true
  def requires_original_data?(_resource, _action), do: false

  @impl true
  def notify(%Ash.Notifier.Notification{resource: GroupMember, action: action, data: member}) do
    case member_kind(action.name) do
      nil -> :ok
      kind -> record(kind, member.group_id, member.user_id, nil)
    end
  end

  def notify(%Ash.Notifier.Notification{resource: HuddlAttendee, action: action, data: attendee}) do
    case attendee_kind(action, attendee) do
      nil -> :ok
      kind -> record_for_huddl(kind, attendee)
    end
  end

  def notify(_notification), do: :ok

  defp member_kind(:join_group), do: :joined
  defp member_kind(:add_member), do: :joined
  defp member_kind(:accept_invitation), do: :accepted_invitation
  defp member_kind(:leave_group), do: :left
  defp member_kind(:remove_member), do: :left
  defp member_kind(_other), do: nil

  defp attendee_kind(%{type: :create, name: :rsvp}, _attendee), do: :rsvped
  defp attendee_kind(%{type: :create, name: :join_waitlist}, _attendee), do: :waitlisted
  defp attendee_kind(%{type: :update, name: :promote_from_waitlist}, _attendee), do: :promoted
  defp attendee_kind(%{type: :destroy}, %{waitlisted_at: nil}), do: :cancelled_rsvp
  defp attendee_kind(%{type: :destroy}, _waitlisted), do: :left_waitlist
  defp attendee_kind(_action, _attendee), do: nil

  defp record_for_huddl(kind, attendee) do
    # The visibility-free read: the primary read hides private huddlz from
    # actorless lookups, and this one runs after the actor's action.
    Huddl
    |> Ash.Query.for_read(:get_for_mutation, %{id: attendee.huddl_id})
    |> Ash.Query.select([:group_id])
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, %{group_id: group_id}} -> record(kind, group_id, attendee.user_id, attendee.huddl_id)
      {:ok, nil} -> report(kind, :huddl_not_found)
      {:error, error} -> report(kind, error)
    end
  end

  defp record(kind, group_id, user_id, huddl_id) do
    GroupActivity
    |> Ash.Changeset.for_create(:record, %{
      kind: kind,
      group_id: group_id,
      user_id: user_id,
      huddl_id: huddl_id
    })
    |> Ash.create(authorize?: false)
    |> case do
      {:ok, _activity} -> :ok
      {:error, error} -> report(kind, error)
    end
  end

  defp report(kind, error) do
    Logger.error("group activity log: could not record #{kind}: #{inspect(error)}")
    :ok
  end
end
