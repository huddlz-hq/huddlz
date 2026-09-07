defmodule Huddlz.Communities.Huddl.Changes.RecipientHelpers do
  @moduledoc """
  Tiny shared helpers for resolving notification recipient sets from
  huddl-related Ash actions. Lifted out of inline change-module code
  once we had a second consumer.
  """

  require Ash.Query

  alias Huddlz.Accounts.User
  alias Huddlz.Communities
  alias Huddlz.Communities.GroupMember
  alias Huddlz.Communities.Huddl
  alias Huddlz.Communities.Huddl.Changes.SeriesRsvpTarget
  alias Huddlz.Communities.Huddl.RecurrenceHelper
  alias Huddlz.Notifications

  @doc """
  Returns the user_ids of every RSVP on the given huddl, optionally
  excluding the actor. Reads with `authorize?: false` because callers
  are running inside an Ash action and the candidate set is system-
  determined, not actor-determined.
  """
  @spec rsvp_user_ids(Ecto.UUID.t(), keyword()) :: [Ecto.UUID.t()]
  def rsvp_user_ids(huddl_id, opts \\ []) do
    actor_id = Keyword.get(opts, :exclude)

    [huddl_id]
    |> Communities.list_huddl_notification_recipients!(authorize?: false)
    |> Enum.map(& &1.user_id)
    |> Enum.uniq()
    |> Enum.reject(&(&1 == actor_id))
  end

  @doc """
  Returns the next summary target and upcoming calendar huddlz for each person
  with an RSVP or waitlist entry on the source
  occurrence or any later occurrence in its recurring series.

  Choosing targets per recipient keeps a whole-series summary useful for
  people who attend different dates and ensures the link points to a huddl
  they can still access after reconciliation.
  """
  @spec series_rsvp_targets(Huddl.t(), keyword()) :: [SeriesRsvpTarget.t()]
  def series_rsvp_targets(%Huddl{} = source, opts \\ []) do
    actor_id = Keyword.get(opts, :exclude)
    huddlz = [source | RecurrenceHelper.future_instances(source)]
    huddlz_by_id = Map.new(huddlz, &{&1.id, &1})
    huddl_ids = Map.keys(huddlz_by_id)

    huddl_ids
    |> Communities.list_huddl_notification_recipients!(authorize?: false)
    |> Enum.reject(&(&1.user_id == actor_id))
    |> Enum.group_by(& &1.user_id)
    |> Enum.map(fn {user_id, attendances} ->
      targets =
        attendances
        |> Enum.map(&Map.fetch!(huddlz_by_id, &1.huddl_id))
        |> Enum.sort_by(& &1.starts_at, DateTime)

      now = DateTime.utc_now()

      calendar_huddlz =
        attendances
        |> Enum.filter(&is_nil(&1.waitlisted_at))
        |> Enum.map(&Map.fetch!(huddlz_by_id, &1.huddl_id))
        |> Enum.filter(
          &(&1.lifecycle_state == :published and DateTime.compare(&1.starts_at, now) == :gt)
        )
        |> Enum.sort_by(& &1.starts_at, DateTime)

      %SeriesRsvpTarget{
        user_id: user_id,
        next_huddl: hd(targets),
        calendar_huddlz: calendar_huddlz
      }
    end)
  end

  @doc """
  Returns the user_ids of every owner and organizer of the given group,
  deduplicated, optionally excluding the actor. Used by the E1/E2 RSVP
  fanout notifiers.
  """
  @spec group_organizer_user_ids(Ecto.UUID.t(), keyword()) :: [Ecto.UUID.t()]
  def group_organizer_user_ids(group_id, opts \\ []) do
    actor_id = Keyword.get(opts, :exclude)

    GroupMember
    |> Ash.Query.filter(group_id == ^group_id and role in [:owner, :organizer])
    |> Ash.Query.select([:user_id])
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.user_id)
    |> Enum.uniq()
    |> Enum.reject(&(&1 == actor_id))
  end

  @doc """
  Pull the actor id out of an Ash.Changeset's private context. Returns
  `nil` when no actor is present (e.g. system-driven actions).
  """
  @spec actor_id(Ash.Changeset.t()) :: Ecto.UUID.t() | nil
  def actor_id(changeset) do
    case actor(changeset) do
      %{id: id} -> id
      _ -> nil
    end
  end

  @doc """
  Pull the actor out of an Ash.Changeset's private context. Returns
  `nil` when no actor is present (e.g. system-driven actions).
  """
  @spec actor(Ash.Changeset.t()) :: struct() | nil
  def actor(changeset) do
    changeset.context[:private][:actor]
  end

  @doc """
  Fan a notification trigger out to a list of user_ids, fetching users
  with `authorize?: false` and skipping any that no longer exist
  (e.g. raced deletion). Used by the C/E-series fanout notifiers.
  """
  @spec deliver_each([Ecto.UUID.t()], atom(), map()) :: :ok | {:error, term()}
  def deliver_each([], _trigger, _payload), do: :ok

  def deliver_each(user_ids, trigger, payload) do
    User
    |> Ash.Query.filter(id in ^user_ids)
    |> Ash.read!(authorize?: false)
    |> Enum.reduce_while(:ok, fn user, :ok ->
      case Notifications.deliver(user, trigger, payload) do
        {:ok, _job} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end
end
