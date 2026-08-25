defmodule Huddlz.BackfillTimeZones do
  @moduledoc """
  One-time data backfill: assigns a best-effort `time_zone` to every
  `Group`/`Huddl` row that still has the resource default (`"Etc/UTC"`),
  geo-deriving from existing coordinates where possible. Never touches
  `starts_at`/`ends_at`. Groups are processed before huddlz so huddlz that
  can't be geo-derived directly inherit their (already-backfilled) group's
  zone.

  Deliberately **not** implemented with `Ash.stream!/2`: the target row set
  (`time_zone == "Etc/UTC"`) shrinks as each row is successfully backfilled,
  and an offset-based streaming strategy re-issues `LIMIT/OFFSET` against
  that same shrinking filtered set on every batch — once a full batch
  succeeds, the next `OFFSET` lands past the end of the (now smaller)
  matching set and the stream silently halts, skipping every row after the
  first batch with no error. (`Huddl`'s primary `:read` action has no
  `pagination` block at all, so `Ash.stream!/2` can't use stable keyset
  pagination for it regardless of `allow_stream_with` — it falls back to
  exactly this unstable offset strategy.) Instead, each pass runs a single
  unpaginated `Ash.read!/2` to collect the *entire* matching row set
  up front, before any row is mutated, then iterates that fixed, in-memory
  list. Legacy backfill row counts are expected to be modest (this is a
  one-time post-deploy cleanup, not an ongoing bulk job), so loading them
  into memory in one query is the simplest correct approach and sidesteps
  the streaming-strategy question entirely.

  Run once via `mix run priv/repo/backfill_time_zones.exs` after this
  feature deploys. Safe to re-run — it's a no-op for rows whose `time_zone`
  isn't `"Etc/UTC"`, and for `"Etc/UTC"` rows without derivable coordinates
  it just re-confirms the same value.
  """

  require Ash.Query

  alias Huddlz.Communities.{Group, Huddl}
  alias Huddlz.Geocoding.TimeZoneLookup

  @spec run() :: :ok
  def run do
    backfill_groups()
    backfill_huddlz()
    :ok
  end

  defp backfill_groups do
    Group
    |> Ash.Query.filter(time_zone == "Etc/UTC")
    |> Ash.read!(authorize?: false)
    |> Enum.each(&backfill_group/1)
  end

  defp backfill_group(%{latitude: lat, longitude: lng} = group)
       when is_number(lat) and is_number(lng) do
    case TimeZoneLookup.from_coordinates(lat, lng) do
      {:ok, time_zone} -> update_time_zone!(group, :update_details, time_zone)
      :error -> :ok
    end
  end

  defp backfill_group(_group), do: :ok

  defp backfill_huddlz do
    Huddl
    |> Ash.Query.filter(time_zone == "Etc/UTC")
    |> Ash.Query.load(:group)
    |> Ash.read!(authorize?: false)
    |> Enum.each(&backfill_huddl/1)
  end

  defp backfill_huddl(%{latitude: lat, longitude: lng} = huddl)
       when is_number(lat) and is_number(lng) do
    case TimeZoneLookup.from_coordinates(lat, lng) do
      {:ok, time_zone} -> update_time_zone!(huddl, :update, time_zone)
      :error -> inherit_group_time_zone(huddl)
    end
  end

  defp backfill_huddl(huddl), do: inherit_group_time_zone(huddl)

  defp inherit_group_time_zone(%{group: %{time_zone: time_zone}} = huddl)
       when is_binary(time_zone) and time_zone != "Etc/UTC" do
    update_time_zone!(huddl, :update, time_zone)
  end

  defp inherit_group_time_zone(_huddl), do: :ok

  defp update_time_zone!(record, action, time_zone) do
    record
    |> Ash.Changeset.for_update(action, %{}, authorize?: false)
    |> Ash.Changeset.force_change_attribute(:time_zone, time_zone)
    |> Ash.update!(authorize?: false)
  end
end
