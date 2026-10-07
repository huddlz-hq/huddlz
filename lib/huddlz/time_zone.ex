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

  @doc """
  Resolves a local time, moving forward out of a daylight saving gap rather
  than failing.

  Generated recurring occurrences use this. A boundless series must not die
  permanently because one of its dates falls in the hour a zone skips, so the
  occurrence happens at the first valid local time instead. `resolve_local/2`
  keeps rejecting a gap, because a time a person typed into a form does not
  exist and they should be told so.
  """
  def resolve_local_forward(%NaiveDateTime{} = local, time_zone) do
    case DateTime.from_naive(local, time_zone) do
      {:ok, datetime} -> {:ok, datetime}
      {:ambiguous, earlier, _later} -> {:ok, earlier}
      {:gap, _before_gap, after_gap} -> {:ok, after_gap}
      {:error, reason} -> {:error, reason}
    end
  end

  def eastern, do: @eastern
end
