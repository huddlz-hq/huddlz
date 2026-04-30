defmodule Huddlz.Communities.Huddl.Changes.RecipientHelpers do
  @moduledoc """
  Tiny shared helpers for resolving notification recipient sets from
  huddl-related Ash actions. Lifted out of inline change-module code
  once we had a second consumer.
  """

  require Ash.Query

  alias Huddlz.Accounts.User
  alias Huddlz.Communities.GroupMember
  alias Huddlz.Communities.HuddlAttendee

  @doc """
  Returns the user_ids of every RSVP on the given huddl, optionally
  excluding the actor. Reads with `authorize?: false` because callers
  are running inside an Ash action and the candidate set is system-
  determined, not actor-determined.
  """
  @spec rsvp_user_ids(Ecto.UUID.t(), keyword()) :: [Ecto.UUID.t()]
  def rsvp_user_ids(huddl_id, opts \\ []) do
    actor_id = Keyword.get(opts, :exclude)

    HuddlAttendee
    |> Ash.Query.filter(huddl_id == ^huddl_id)
    |> Ash.Query.select([:user_id])
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.user_id)
    |> Enum.uniq()
    |> Enum.reject(&(&1 == actor_id))
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
    case changeset.context[:private][:actor] do
      %{id: id} -> id
      _ -> nil
    end
  end

  @doc """
  Look up a user's `display_name` by id, falling back to the given
  string if the user can't be loaded. Used to render the rsvper's name
  in E1/E2 fanout payloads.
  """
  @spec user_display_name(Ecto.UUID.t() | nil, String.t()) :: String.t()
  def user_display_name(nil, fallback), do: fallback

  def user_display_name(user_id, fallback) do
    case Ash.get(User, user_id, authorize?: false) do
      {:ok, user} -> to_string(user.display_name)
      _ -> fallback
    end
  end
end
