defmodule Huddlz.Admin.CopyStats do
  @moduledoc """
  The Copies figures of the admin overview: how many huddlz organizers
  created by copying another huddl, and whether the source had already
  happened when they copied it.

  Counts only, like the Drop-ins panel. Read from the audit history alone:
  a copy's `:create` version carries `copied_from_id` metadata, the organizer
  who made it and a snapshot of the new huddl. The huddl itself keeps no link
  to its source, and history is kept for two years (ADR-0007).

  Called by `Huddlz.Admin.PlatformStats`, which has already narrowed the
  window to the groups the administrator may see; the reads here trust that
  boundary.
  """

  require Ash.Query

  alias Huddlz.Communities.Huddl

  @doc """
  The figures for a window.

    * `count`, `previous` — copies made in the period, and in the period
      before (nil unless the records cover all of it)
    * `organizers`, `groups` — the distinct organizers who made the copies
      of the period, and the distinct groups they made them in
    * `past`, `upcoming` — the copies of the period split by whether the
      source had ended by the time it was copied
    * `measured_since` — the date of the earliest copy on record when the
      period reaches back before it, otherwise nil
  """
  def compute(%{start: start, previous_start: previous_start} = window) do
    copies = copies(window)
    {current, previous} = Enum.split_with(copies, &(DateTime.compare(&1.at, start) != :lt))
    earliest = earliest_copy()
    sources = source_ends(current, window.actor)
    {past, upcoming} = Enum.split_with(current, &past_source?(&1, sources))

    %{
      count: length(current),
      previous: if(covered?(earliest, previous_start), do: length(previous)),
      organizers: current |> Enum.map(& &1.actor_id) |> Enum.uniq() |> length(),
      groups: current |> Enum.map(& &1.group_id) |> Enum.uniq() |> length(),
      past: length(past),
      upcoming: length(upcoming),
      measured_since: if(not covered?(earliest, start), do: DateTime.to_date(earliest))
    }
  end

  # Copies made since the previous period began, in the groups the
  # administrator can see.
  defp copies(%{previous_start: since, now: now, group_ids: group_ids}) do
    Huddl.Version
    |> Ash.Query.filter(
      version_action_name == :create and not is_nil(copied_from_id) and
        version_inserted_at >= ^since and version_inserted_at <= ^now
    )
    |> Ash.Query.select([:copied_from_id, :actor_id, :changes, :version_inserted_at])
    |> Ash.read!(authorize?: false)
    |> Enum.map(
      &%{
        at: &1.version_inserted_at,
        source_id: &1.copied_from_id,
        actor_id: &1.actor_id,
        group_id: snapshot(&1.changes, :group_id)
      }
    )
    |> Enum.filter(&(&1.group_id in group_ids))
  end

  defp earliest_copy do
    Huddl.Version
    |> Ash.Query.filter(version_action_name == :create and not is_nil(copied_from_id))
    |> Ash.Query.select([:version_inserted_at])
    |> Ash.Query.sort(version_inserted_at: :asc)
    |> Ash.Query.limit(1)
    |> Ash.read_one!(authorize?: false)
    |> case do
      %{version_inserted_at: at} -> at
      nil -> nil
    end
  end

  # The records cover a period when the first copy came after it began.
  defp covered?(nil, _from), do: true
  defp covered?(earliest, from), do: DateTime.compare(earliest, from) != :gt

  # A source had happened when it ended before the copy was made. Its end
  # is read as the source stood then: its latest version at or before the
  # copy, or its current row when it has no history (seeded huddlz).
  defp past_source?(copy, sources) do
    case ends_at_when_copied(Map.get(sources, copy.source_id, %{}), copy.at) do
      nil -> false
      ends_at -> DateTime.compare(ends_at, copy.at) != :gt
    end
  end

  defp ends_at_when_copied(%{versions: versions, current: current}, at) do
    versions
    |> Enum.filter(&(DateTime.compare(&1.at, at) != :gt))
    |> Enum.max_by(& &1.at, DateTime, fn -> nil end)
    |> case do
      %{ends_at: ends_at} -> ends_at
      nil -> current
    end
  end

  defp ends_at_when_copied(_unknown, _at), do: nil

  defp source_ends([], _actor), do: %{}

  defp source_ends(copies, actor) do
    ids = copies |> Enum.map(& &1.source_id) |> Enum.uniq()

    versions =
      Huddl.Version
      |> Ash.Query.filter(version_source_id in ^ids)
      |> Ash.Query.select([:version_source_id, :changes, :version_inserted_at])
      |> Ash.read!(authorize?: false)
      |> Enum.group_by(& &1.version_source_id, fn version ->
        %{
          at: version.version_inserted_at,
          ends_at: parse_datetime(snapshot(version.changes, :ends_at))
        }
      end)

    # The visibility filter runs even unauthorized, so drafts and private
    # huddlz need the administrator as the actor.
    current =
      Huddl
      |> Ash.Query.filter(id in ^ids)
      |> Ash.Query.select([:id, :ends_at])
      |> Ash.read!(authorize?: false, actor: actor)
      |> Map.new(&{&1.id, &1.ends_at})

    Map.new(ids, fn id ->
      {id, %{versions: Map.get(versions, id, []), current: Map.get(current, id)}}
    end)
  end

  # Snapshots come back from the database with string keys.
  defp snapshot(changes, key), do: Map.get(changes, key) || Map.get(changes, to_string(key))

  defp parse_datetime(%DateTime{} = at), do: at

  defp parse_datetime(at) when is_binary(at) do
    case DateTime.from_iso8601(at) do
      {:ok, datetime, _offset} -> datetime
      _invalid -> nil
    end
  end

  defp parse_datetime(_missing), do: nil
end
