defmodule Huddlz.BackfillTimeZones do
  @moduledoc """
  One-time data backfill: assigns a best-effort `time_zone` to every
  `Group`/`Huddl` row that still has the resource default (`"Etc/UTC"`),
  geo-deriving from existing coordinates where possible. Never touches
  `starts_at`/`ends_at`. Groups are processed before huddlz so huddlz that
  can't be geo-derived directly inherit their (already-backfilled) group's
  zone.

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
    |> Ash.stream!(authorize?: false, allow_stream_with: :full_read)
    |> Stream.each(&backfill_group/1)
    |> Stream.run()
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
    |> Ash.stream!(authorize?: false, allow_stream_with: :full_read)
    |> Stream.each(&backfill_huddl/1)
    |> Stream.run()
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
