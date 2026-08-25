defmodule Huddlz.Notifications.DateTimeFormatter do
  @moduledoc """
  Shared date/time formatting for notification copy.
  """

  alias Huddlz.DateTimeFormatting

  @default_time_zone "Etc/UTC"
  @starts_at_format "%a %b %-d, %Y at %-I:%M %p %Z"

  def time_zone_from_payload(%{"time_zone" => time_zone}), do: time_zone
  def time_zone_from_payload(%{"timezone" => time_zone}), do: time_zone
  def time_zone_from_payload(_), do: nil

  def format_starts_at(%DateTime{} = datetime, time_zone \\ @default_time_zone) do
    datetime
    |> DateTimeFormatting.shift(time_zone)
    |> Calendar.strftime(@starts_at_format)
  end

  def format_starts_at_iso(iso, time_zone \\ @default_time_zone, fallback \\ "the scheduled time")

  def format_starts_at_iso(iso, time_zone, fallback) when is_binary(iso) do
    case DateTime.from_iso8601(iso) do
      {:ok, datetime, _offset} -> format_starts_at(datetime, time_zone)
      _ -> fallback
    end
  end

  def format_starts_at_iso(_, _, fallback), do: fallback
end
