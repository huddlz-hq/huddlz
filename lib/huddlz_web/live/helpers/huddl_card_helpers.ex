defmodule HuddlzWeb.Live.Helpers.HuddlCardHelpers do
  @moduledoc """
  Shared formatting helpers for huddl card listings (discover, huddlz,
  group show, calendar): date block, `event_type` tag, RSVP count labels,
  and relative times.
  """

  def tag_variant(:in_person), do: :in_person
  def tag_variant(:virtual), do: :online
  def tag_variant(:hybrid), do: :hybrid

  def tag_label(:in_person), do: "In person"
  def tag_label(:virtual), do: "Online"
  def tag_label(:hybrid), do: "Hybrid"

  def huddl_month(%{starts_at: %DateTime{}} = huddl),
    do: huddl |> local_starts_at() |> Calendar.strftime("%b") |> String.upcase()

  def huddl_day(%{starts_at: %DateTime{}} = huddl),
    do: huddl |> local_starts_at() |> Calendar.strftime("%-d")

  def format_meta_when(%{starts_at: %DateTime{}} = huddl) do
    datetime = local_starts_at(huddl)

    "#{Calendar.strftime(datetime, "%a")} · " <>
      "#{Calendar.strftime(datetime, "%-I:%M %p")} #{datetime.zone_abbr}"
  end

  def local_starts_at(%{starts_at: datetime, time_zone: time_zone}),
    do: DateTime.shift_zone!(datetime, time_zone)

  def rsvp_label(%{rsvp_count: count, max_attendees: max}) when is_integer(max) and max > 0,
    do: "#{count} / #{max} RSVPs"

  def rsvp_label(%{rsvp_count: 1}), do: "1 RSVP"
  def rsvp_label(%{rsvp_count: count}), do: "#{count} RSVPs"

  @doc """
  How far a moment is from now, in the words a card foot or agenda entry
  uses: "tomorrow", "3 days away", "2 weeks ago", or the date once it is
  more than a month out.
  """
  def relative_time(%DateTime{} = dt) do
    diff_seconds = DateTime.diff(dt, DateTime.utc_now(), :second)
    abs_seconds = abs(diff_seconds)
    future? = diff_seconds >= 0

    cond do
      abs_seconds < 3600 -> if future?, do: "starting soon", else: "just ended"
      abs_seconds < 86_400 -> format_hours(div(abs_seconds, 3600), future?)
      abs_seconds < 7 * 86_400 -> format_days(div(abs_seconds, 86_400), future?)
      abs_seconds < 30 * 86_400 -> format_weeks(div(abs_seconds, 7 * 86_400), future?)
      true -> Calendar.strftime(dt, "%b %d, %Y")
    end
  end

  defp format_hours(1, true), do: "1 hour away"
  defp format_hours(n, true), do: "#{n} hours away"
  defp format_hours(1, false), do: "1 hour ago"
  defp format_hours(n, false), do: "#{n} hours ago"

  defp format_days(1, true), do: "tomorrow"
  defp format_days(n, true), do: "#{n} days away"
  defp format_days(1, false), do: "yesterday"
  defp format_days(n, false), do: "#{n} days ago"

  defp format_weeks(1, true), do: "1 week away"
  defp format_weeks(n, true), do: "#{n} weeks away"
  defp format_weeks(1, false), do: "1 week ago"
  defp format_weeks(n, false), do: "#{n} weeks ago"
end
