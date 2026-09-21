defmodule Huddlz.Communities.RsvpMoment do
  @moduledoc """
  When an RSVP was made. For most it is when the row was created. A row that
  began on the waitlist was created when the person joined the waitlist, and
  promotion does not touch that time, so its RSVP was made at the promotion
  the group activity log records.

  One rule for every figure that asks when someone RSVPd: the signup curves
  and drop-in lines of a group's overview, and the platform's RSVP and
  drop-in figures.
  """

  require Ash.Query

  alias Huddlz.Communities.{GroupActivity, HuddlAttendee}

  @type key :: {huddl_id :: String.t(), user_id :: String.t()}
  @type scope :: {:group, String.t()} | {:huddlz, [String.t()]}

  @doc """
  The standing RSVPs made since a moment, as `%{user_id, huddl_id, at}`,
  within one group or a set of huddlz. A row that joined the waitlist before
  the moment and was promoted after it is included; one promoted before it
  is not. The reads skip authorization: callers have already decided the
  actor may see these figures.
  """
  @spec standing_since(scope(), DateTime.t()) :: [map()]
  def standing_since(scope, since) do
    promotions =
      GroupActivity
      |> Ash.Query.filter(kind == :promoted and occurred_at >= ^since)
      |> in_scope(scope, :activity)
      |> Ash.Query.select([:huddl_id, :user_id, :kind, :occurred_at])
      |> Ash.read!(authorize?: false)
      |> promotions()

    promoted_user_ids = promotions |> Map.keys() |> Enum.map(&elem(&1, 1)) |> Enum.uniq()

    HuddlAttendee
    |> Ash.Query.filter(
      is_nil(waitlisted_at) and (rsvped_at >= ^since or user_id in ^promoted_user_ids)
    )
    |> in_scope(scope, :attendee)
    |> Ash.Query.select([:user_id, :huddl_id, :rsvped_at])
    |> Ash.read!(authorize?: false)
    |> Enum.map(&%{user_id: &1.user_id, huddl_id: &1.huddl_id, at: at(&1, promotions)})
    |> Enum.filter(&(DateTime.compare(&1.at, since) != :lt))
  end

  defp in_scope(query, {:group, group_id}, :activity),
    do: Ash.Query.filter(query, group_id == ^group_id)

  defp in_scope(query, {:group, group_id}, :attendee),
    do: Ash.Query.filter(query, huddl.group_id == ^group_id)

  defp in_scope(query, {:huddlz, huddl_ids}, _resource),
    do: Ash.Query.filter(query, huddl_id in ^huddl_ids)

  @doc """
  The latest promotion per huddl and person among activity entries. Entries
  of other kinds are ignored.
  """
  @spec promotions([map()]) :: %{key() => DateTime.t()}
  def promotions(entries) do
    entries
    |> Enum.filter(&(&1.kind == :promoted))
    |> Enum.group_by(&{&1.huddl_id, &1.user_id}, & &1.occurred_at)
    |> Map.new(fn {key, times} -> {key, Enum.max(times, DateTime)} end)
  end

  @doc """
  When the standing row's RSVP was made. A fresh RSVP made after an older
  promotion of the same person keeps its own, later time.
  """
  @spec at(%{huddl_id: String.t(), user_id: String.t(), rsvped_at: DateTime.t()}, map()) ::
          DateTime.t()
  def at(row, promotions) do
    case promotions[{row.huddl_id, row.user_id}] do
      nil -> row.rsvped_at
      promoted_at -> Enum.max([row.rsvped_at, promoted_at], DateTime)
    end
  end
end
