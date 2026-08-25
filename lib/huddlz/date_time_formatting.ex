defmodule Huddlz.DateTimeFormatting do
  @moduledoc """
  Shared timezone resolution and safe shifting, used by both `HuddlzWeb`
  display helpers and `Huddlz.Notifications`.
  """

  @default_time_zone "Etc/UTC"

  @doc """
  Resolves the zone to display a huddl's time in for a given viewer:
  the viewer's `time_zone_preference` if set, else the huddl's own
  `time_zone`, else `"Etc/UTC"`.
  """
  @spec resolve_zone(map() | nil, map() | nil) :: String.t()
  def resolve_zone(user, huddl) do
    cond do
      present?(user && Map.get(user, :time_zone_preference)) ->
        user.time_zone_preference

      present?(huddl && Map.get(huddl, :time_zone)) ->
        huddl.time_zone

      true ->
        @default_time_zone
    end
  end

  @doc """
  Resolves a viewer-only reference zone (no specific huddl involved — e.g.
  "what day is today" on the calendar grid): the viewer's `time_zone_preference`
  if set, else the given browser-detected zone, else `"Etc/UTC"`.
  """
  @spec resolve_viewer_zone(map() | nil, String.t() | nil) :: String.t()
  def resolve_viewer_zone(user, browser_time_zone) do
    cond do
      present?(user && Map.get(user, :time_zone_preference)) ->
        user.time_zone_preference

      present?(browser_time_zone) ->
        browser_time_zone

      true ->
        @default_time_zone
    end
  end

  @doc """
  Interprets `date` and `time` as wall time in `time_zone`.

  Wraps `DateTime.new/3` so that its two DST outcomes can't go unhandled:

    * an *ambiguous* wall time (the hour repeated by a fall-back transition)
      resolves to `{:ok, earlier_instant}` — the first of the two, i.e. still
      in the pre-transition offset;
    * a *nonexistent* wall time (the hour skipped by a spring-forward
      transition) returns `{:gap, just_before, just_after}` for the caller to
      reject or snap, since no instant matches what was asked for.

  A missing or unrecognized zone falls back to `"Etc/UTC"`.
  """
  @spec resolve_wall_time(Date.t(), Time.t(), String.t() | nil) ::
          {:ok, DateTime.t()} | {:gap, DateTime.t(), DateTime.t()} | {:error, term()}
  def resolve_wall_time(date, time, time_zone) do
    case DateTime.new(date, time, normalize(time_zone)) do
      {:ok, datetime} -> {:ok, datetime}
      {:ambiguous, earlier, _later} -> {:ok, earlier}
      {:gap, just_before, just_after} -> {:gap, just_before, just_after}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Shifts a `DateTime` into `time_zone`, falling back to `"Etc/UTC"` if the
  zone is missing or unrecognized.
  """
  @spec shift(DateTime.t(), String.t() | nil) :: DateTime.t()
  def shift(%DateTime{} = datetime, time_zone) do
    case DateTime.shift_zone(datetime, normalize(time_zone)) do
      {:ok, shifted} -> shifted
      _ -> DateTime.shift_zone!(datetime, @default_time_zone)
    end
  end

  defp present?(value), do: is_binary(value) and value != ""

  defp normalize(time_zone) when is_binary(time_zone) and time_zone != "", do: time_zone
  defp normalize(_), do: @default_time_zone
end
