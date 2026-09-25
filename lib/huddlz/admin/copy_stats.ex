defmodule Huddlz.Admin.CopyStats do
  @moduledoc """
  The Copies figures of the admin overview: how many huddlz organizers
  created by copying another huddl, and whether the source had already
  happened when they copied it.

  Counts only, like the Drop-ins panel. Read from the audit history alone:
  a copy's `:create` version carries `copied_from_id` metadata, the organizer
  who made it and a snapshot of the new huddl. The huddl itself keeps no link
  to its source, and history is kept for two years (ADR-0007).

  Called behind the administrator-only platform overview action. ADR-0004
  permits these platform-wide aggregate counts across private groups, private
  huddlz, drafts and deleted copies while their history is retained. This
  exception exposes no individual records and grants no content access.
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
    * `unknown` — older copies whose source timing was not recorded
    * `measured_since` — the later of deployment and retention start when the
      period reaches back before it, otherwise nil
  """
  def compute(%{start: start, previous_start: previous_start} = window) do
    copies = copies(window)
    {current, previous} = Enum.split_with(copies, &(DateTime.compare(&1.at, start) != :lt))
    measured_from = measured_from(window.now)
    sources = Enum.frequencies_by(current, &source_timing/1)

    %{
      count: length(current),
      previous: if(covered?(measured_from, previous_start), do: length(previous)),
      organizers: current |> Enum.map(& &1.organizer_id) |> Enum.uniq() |> length(),
      groups: current |> Enum.map(& &1.group_id) |> Enum.uniq() |> length(),
      past: Map.get(sources, :past, 0),
      upcoming: Map.get(sources, :upcoming, 0),
      unknown: Map.get(sources, :unknown, 0),
      measured_since: if(not covered?(measured_from, start), do: DateTime.to_date(measured_from))
    }
  end

  # Count retained audit facts across the platform, independent of the
  # administrator's memberships and the copied huddl's current visibility.
  defp copies(%{previous_start: since, now: now}) do
    Huddl.Version
    |> Ash.Query.filter(
      version_action_name == :create and not is_nil(copied_from_id) and
        version_inserted_at >= ^since and version_inserted_at <= ^now
    )
    |> Ash.Query.select([:copied_source_ends_at, :changes, :version_inserted_at])
    |> Ash.read!(authorize?: false)
    |> Enum.map(
      &%{
        at: &1.version_inserted_at,
        source_ends_at: &1.copied_source_ends_at,
        organizer_id: snapshot(&1.changes, :creator_id),
        group_id: snapshot(&1.changes, :group_id)
      }
    )
  end

  defp measured_from(now) do
    started_at = Ash.read_one!(Huddlz.Admin.CopyMeasurement, authorize?: false).started_at
    retained_from = DateTime.add(now, -730, :day)
    Enum.max([started_at, retained_from], DateTime)
  end

  defp covered?(from, start), do: DateTime.compare(from, start) != :gt

  defp source_timing(%{source_ends_at: nil}), do: :unknown

  defp source_timing(%{source_ends_at: ends_at, at: at}) do
    if DateTime.compare(ends_at, at) == :gt, do: :upcoming, else: :past
  end

  # Snapshots come back from the database with string keys.
  defp snapshot(changes, key), do: Map.get(changes, key) || Map.get(changes, to_string(key))
end
