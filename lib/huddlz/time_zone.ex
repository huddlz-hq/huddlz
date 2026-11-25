defmodule Huddlz.TimeZone do
  @moduledoc """
  Helpers for validating and presenting canonical IANA time-zone identifiers.
  """

  @eastern "America/New_York"

  def canonical?(time_zone) when is_binary(time_zone) do
    time_zone in Tzdata.canonical_zone_list()
  end

  def canonical?(_time_zone), do: false

  def canonical_or_eastern(time_zone) do
    if canonical?(time_zone), do: time_zone, else: @eastern
  end

  def resolve_local(%Date{} = date, %Time{} = time, time_zone) do
    date
    |> NaiveDateTime.new!(time)
    |> resolve_local(time_zone)
  end

  def resolve_local(%NaiveDateTime{} = local, time_zone) do
    case DateTime.from_naive(local, time_zone) do
      {:ok, datetime} -> {:ok, datetime}
      {:ambiguous, earlier, _later} -> {:ok, earlier}
      {:gap, _before_gap, _after_gap} -> {:error, :daylight_saving_gap}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Resolves a wall-clock start and adds the elapsed duration in that zone."
  def resolve_interval(%Date{} = date, %Time{} = time, minutes, time_zone)
      when is_integer(minutes) and is_binary(time_zone) do
    with {:ok, starts_at} <- resolve_local(date, time, time_zone) do
      {:ok, starts_at, DateTime.add(starts_at, minutes, :minute)}
    end
  end

  def resolve_interval(_date, _time, _minutes, _time_zone), do: :incomplete

  def eastern, do: @eastern
end
