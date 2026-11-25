defmodule HuddlzWeb.HuddlSchedule do
  @moduledoc "Formats the local schedule shown on a huddl and its share image."

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
