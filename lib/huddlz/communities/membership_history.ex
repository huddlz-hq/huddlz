defmodule Huddlz.Communities.MembershipHistory do
  @moduledoc """
  Whether a person belonged to a group at a past moment, and when they
  joined after one. The one rule behind every drop-in figure, on the admin
  overview and on a group's.

  Three sources, any of which can say "a member then":

    * the membership row: a member since it was created;
    * the retained snapshot of a membership that has ended, which holds the
      whole interval. It is what covers a founding owner who transfers the
      group and leaves: their membership is deliberately absent from the
      activity log;
    * the group activity log: the last joined, accepted or left entry at or
      before the moment.

  The reads skip authorization; callers have already decided the actor may
  see these groups' figures.
  """

  require Ash.Query

  alias Huddlz.Communities.{GroupActivity, GroupMember}

  @membership_kinds [:joined, :accepted_invitation, :left]
  @join_kinds [:joined, :accepted_invitation]

  @type pair :: {user_id :: String.t(), group_id :: String.t()}
  @opaque t :: %{members: map(), log: map(), ended: map()}

  @doc """
  The history of these people in these groups. `since` bounds the ended
  memberships read: one that ended before it cannot cover a later moment.
  Pass nil to read every retained one.
  """
  @spec load([String.t()], [String.t()], DateTime.t() | nil) :: t()
  def load(_group_ids, [], _since), do: %{members: %{}, log: %{}, ended: %{}}

  def load(group_ids, user_ids, since) do
    user_ids = Enum.uniq(user_ids)

    members =
      GroupMember
      |> Ash.Query.filter(group_id in ^group_ids and user_id in ^user_ids)
      |> Ash.Query.select([:user_id, :group_id, :created_at, :join_source])
      |> Ash.read!(authorize?: false)
      |> Map.new(&{pair(&1), &1})

    log =
      GroupActivity
      |> Ash.Query.filter(
        group_id in ^group_ids and user_id in ^user_ids and kind in ^@membership_kinds
      )
      |> Ash.Query.select([:user_id, :group_id, :kind, :occurred_at, :source])
      |> Ash.Query.sort(occurred_at: :asc)
      |> Ash.read!(authorize?: false)
      |> Enum.group_by(&pair/1)

    %{members: members, log: log, ended: ended(group_ids, user_ids, since)}
  end

  @doc "The key a person in a group is looked up by."
  @spec pair(%{user_id: String.t(), group_id: String.t()}) :: pair()
  def pair(%{user_id: user_id, group_id: group_id}), do: {user_id, group_id}

  @doc "Whether the person belonged to the group at the moment."
  @spec member_at?(t(), pair(), DateTime.t()) :: boolean()
  def member_at?(history, pair, at) do
    Enum.any?(Map.get(history.ended, pair, []), fn membership ->
      DateTime.compare(membership.since, at) != :gt and
        DateTime.compare(at, membership.until) == :lt
    end) or member_by_row_or_log?(history, pair, at)
  end

  @doc "Whether the person belongs to the group now."
  @spec member_now?(t(), pair()) :: boolean()
  def member_now?(history, pair), do: is_map_key(history.members, pair)

  @doc """
  The first join after a moment, as `{at, source}`, or nil. The membership
  row and its log entry describe the same join; the log alone remembers a
  join the person has since left.
  """
  @spec join_after(t(), pair(), DateTime.t()) :: {DateTime.t(), atom() | nil} | nil
  def join_after(%{members: members, log: log}, pair, at) do
    from_row =
      case members[pair] do
        %{created_at: since, join_source: source} when not is_nil(since) -> [{since, source}]
        _ -> []
      end

    from_log =
      for %{kind: kind} = entry <- log[pair] || [], kind in @join_kinds do
        {entry.occurred_at, entry.source}
      end

    (from_row ++ from_log)
    |> Enum.filter(fn {joined_at, _source} -> DateTime.compare(joined_at, at) == :gt end)
    |> Enum.min_by(fn {joined_at, _source} -> DateTime.to_unix(joined_at, :microsecond) end, fn ->
      nil
    end)
  end

  defp ended(group_ids, user_ids, since) do
    GroupMember.Version
    |> Ash.Query.filter(
      version_action_type == :destroy and
        get_path(changes, [:group_id]) in ^group_ids and
        get_path(changes, [:user_id]) in ^user_ids
    )
    |> ended_since(since)
    |> Ash.Query.select([:changes, :version_inserted_at])
    |> Ash.read!(authorize?: false)
    |> Enum.map(fn version ->
      {:ok, since, _offset} = DateTime.from_iso8601(version.changes["created_at"])

      %{
        group_id: version.changes["group_id"],
        user_id: version.changes["user_id"],
        since: since,
        until: version.version_inserted_at
      }
    end)
    |> Enum.group_by(&pair/1)
  end

  defp ended_since(query, nil), do: query
  defp ended_since(query, since), do: Ash.Query.filter(query, version_inserted_at >= ^since)

  defp member_by_row_or_log?(%{members: members, log: log}, pair, at) do
    case members[pair] do
      %{created_at: since} when not is_nil(since) ->
        DateTime.compare(since, at) != :gt or belonged_by_log?(log[pair], at)

      _ ->
        belonged_by_log?(log[pair], at)
    end
  end

  # The last membership entry at or before the moment decides.
  defp belonged_by_log?(nil, _at), do: false

  defp belonged_by_log?(entries, at) do
    entries
    |> Enum.take_while(&(DateTime.compare(&1.occurred_at, at) != :gt))
    |> List.last()
    |> case do
      %{kind: kind} when kind in @join_kinds -> true
      _ -> false
    end
  end
end
