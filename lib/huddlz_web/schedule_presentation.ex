defmodule HuddlzWeb.SchedulePresentation do
  @moduledoc """
  Builds Calendar-local card labels and authoritative huddl-detail labels.
  """

  defstruct [:month, :day, :primary, :secondary]

  def card(huddl, display_time_zone) do
    {display_starts_at, _display_ends_at} = local_schedule(huddl, display_time_zone)
    {huddl_starts_at, _huddl_ends_at} = local_schedule(huddl, huddl.time_zone)

    %__MODULE__{
      month: Calendar.strftime(display_starts_at, "%b") |> String.upcase(),
      day: Calendar.strftime(display_starts_at, "%-d"),
      primary: Calendar.strftime(display_starts_at, "%a · %-I:%M %p %Z"),
      secondary: card_huddl_local(huddl_starts_at, huddl.time_zone, display_time_zone)
    }
  end

  def authoritative_card(huddl), do: card(huddl, huddl.time_zone)

  def authoritative_date(huddl) do
    {starts_at, _ends_at} = local_schedule(huddl, huddl.time_zone)
    Calendar.strftime(starts_at, "%a, %b %-d")
  end

  def detail(huddl) do
    {huddl_starts_at, huddl_ends_at} = local_schedule(huddl, huddl.time_zone)

    %__MODULE__{
      primary: detail_label(huddl_starts_at, huddl_ends_at),
      secondary: nil
    }
  end

  defp card_huddl_local(_starts_at, time_zone, time_zone), do: nil

  defp card_huddl_local(starts_at, _huddl_time_zone, _display_time_zone) do
    Calendar.strftime(starts_at, "%-I:%M %p %Z at the huddl")
  end

  defp detail_label(starts_at, ends_at) do
    abbreviation = Calendar.strftime(starts_at, "%Z")

    cond do
      ends_at && same_day?(starts_at, ends_at) ->
        "#{short_date(starts_at)} · #{time(starts_at)} – #{time(ends_at)} #{abbreviation}"

      ends_at ->
        "#{short_date(starts_at)} #{time(starts_at)} → #{short_date(ends_at)} #{time(ends_at)} #{abbreviation}"

      true ->
        "#{short_date(starts_at)} · #{time(starts_at)} #{abbreviation}"
    end
  end

  defp local_schedule(huddl, time_zone) do
    {
      DateTime.shift_zone!(huddl.starts_at, time_zone),
      shift_optional(huddl.ends_at, time_zone)
    }
  end

  defp shift_optional(nil, _time_zone), do: nil
  defp shift_optional(datetime, time_zone), do: DateTime.shift_zone!(datetime, time_zone)

  defp same_day?(first, second), do: DateTime.to_date(first) == DateTime.to_date(second)
  defp short_date(datetime), do: Calendar.strftime(datetime, "%a, %b %-d")
  defp time(datetime), do: Calendar.strftime(datetime, "%-I:%M %p")
end
