defmodule HuddlzWeb.HuddlSchedule do
  @moduledoc "Formats huddl schedules in the huddl's own time zone."

  def short_date(huddl), do: huddl |> local_starts_at() |> Calendar.strftime("%b %-d")

  def start_time(huddl), do: huddl |> local_starts_at() |> Calendar.strftime("%-I:%M %p %Z")

  def local_starts_at(%{starts_at: starts_at, time_zone: zone}),
    do: DateTime.shift_zone!(starts_at, zone)

  def format_range(%{starts_at: starts_at, ends_at: nil, time_zone: zone}) do
    starts_at |> DateTime.shift_zone!(zone) |> Calendar.strftime("%a, %b %-d · %-I:%M %p %Z")
  end

  def format_range(%{starts_at: starts_at, ends_at: ends_at, time_zone: zone}) do
    first = DateTime.shift_zone!(starts_at, zone)
    last = DateTime.shift_zone!(ends_at, zone)
    start_format = if first.zone_abbr == last.zone_abbr, do: "%-I:%M %p", else: "%-I:%M %p %Z"

    if DateTime.to_date(first) == DateTime.to_date(last) do
      Calendar.strftime(first, "%a, %b %-d · " <> start_format) <>
        " – " <> Calendar.strftime(last, "%-I:%M %p %Z")
    else
      Calendar.strftime(first, "%a, %b %-d " <> start_format) <>
        " → " <> Calendar.strftime(last, "%a, %b %-d %-I:%M %p %Z")
    end
  end
end
