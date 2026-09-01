defmodule Huddlz.Notifications.ICS do
  @moduledoc """
  Generates `.ics` (iCalendar) attachments for huddl reminder and confirmation
  emails.

  Used by senders that need to give the recipient a "Add to calendar" experience
  (E3 RSVP confirmation, D1 24-hour reminder, D2 1-hour reminder).
  """

  alias Huddlz.Communities.Huddl

  @seconds_per_minute 60

  @doc """
  Build an .ics attachment payload for a single huddl.

  Returns `{filename, content}` where `content` is a UTF-8 binary suitable for
  passing to `Swoosh.Email.attachment/2` as the `body`.
  """
  @spec event_for(Huddl.t()) :: {String.t(), String.t()}
  def event_for(%Huddl{} = huddl) do
    local_start = DateTime.shift_zone!(huddl.starts_at, huddl.time_zone)
    local_end = DateTime.shift_zone!(huddl.ends_at, huddl.time_zone)

    event = %ICal.Event{
      uid: "huddl-#{huddl.id}@huddlz.com",
      dtstamp: DateTime.utc_now() |> DateTime.truncate(:second),
      dtstart: DateTime.truncate(local_start, :second),
      dtend: DateTime.truncate(local_end, :second),
      summary: huddl.title,
      description: build_description(huddl),
      location: build_location(huddl),
      url: huddl.virtual_link
    }

    calendar =
      %ICal{
        events: [event],
        timezones: [timezone_component(huddl.time_zone, local_start, local_end)]
      }
      |> ICal.set_vendor("huddlz")

    content = calendar |> ICal.to_ics() |> IO.iodata_to_binary()
    {"huddl.ics", content}
  end

  defp build_description(%Huddl{description: nil, virtual_link: nil}), do: ""
  defp build_description(%Huddl{description: nil, virtual_link: link}), do: "Join: #{link}"
  defp build_description(%Huddl{description: desc, virtual_link: nil}), do: desc

  defp build_description(%Huddl{description: desc, virtual_link: link}) do
    "#{desc}\n\nJoin: #{link}"
  end

  defp build_location(%Huddl{physical_location: nil, virtual_link: link}) when is_binary(link),
    do: link

  defp build_location(%Huddl{physical_location: place}), do: place

  defp timezone_component(time_zone, local_start, local_end) do
    first_year = min(local_start.year, local_end.year) - 1
    last_year = max(local_start.year, local_end.year) + 1
    window_start = gregorian_seconds(first_year, 1, 1)
    window_end = gregorian_seconds(last_year + 1, 1, 1)
    {:ok, periods} = Tzdata.periods(time_zone)

    indexed_periods = Enum.with_index(periods)

    observances =
      indexed_periods
      |> Enum.filter(fn {period, _index} -> overlaps?(period, window_start, window_end) end)
      |> Enum.map(fn {period, index} ->
        previous = previous_period(periods, index)
        observance(period, previous, window_start)
      end)

    {standard, daylight} = Enum.split_with(observances, &(&1.kind == :standard))

    %ICal.Timezone{
      id: time_zone,
      standard: Enum.map(standard, & &1.properties),
      daylight: Enum.map(daylight, & &1.properties)
    }
  end

  defp observance(period, previous, window_start) do
    current_offset = total_offset(period)

    {starts_at, previous_offset} =
      case period.from.utc do
        from when is_integer(from) and from >= window_start ->
          {local_transition(from, total_offset(previous)), total_offset(previous)}

        _before_window ->
          {naive_datetime(window_start), current_offset}
      end

    %{
      kind: if(period.std_off == 0, do: :standard, else: :daylight),
      properties: %ICal.Timezone.Properties{
        dtstart: starts_at,
        offsets: %{
          from: format_offset(previous_offset),
          to: format_offset(current_offset)
        },
        names: [period.zone_abbr]
      }
    }
  end

  defp overlaps?(period, window_start, window_end) do
    before_window_end?(period.from.utc, window_end) and
      after_window_start?(period.until.utc, window_start)
  end

  defp before_window_end?(:min, _window_end), do: true
  defp before_window_end?(:max, _window_end), do: false
  defp before_window_end?(from, window_end), do: from < window_end

  defp after_window_start?(:max, _window_start), do: true
  defp after_window_start?(:min, _window_start), do: false
  defp after_window_start?(until, window_start), do: until > window_start

  defp previous_period(_periods, 0), do: nil
  defp previous_period(periods, index), do: Enum.at(periods, index - 1)

  defp total_offset(nil), do: 0
  defp total_offset(period), do: period.utc_off + period.std_off

  defp local_transition(utc_seconds, previous_offset) do
    utc_seconds
    |> Kernel.+(previous_offset)
    |> naive_datetime()
  end

  defp naive_datetime(gregorian_seconds) do
    gregorian_seconds
    |> :calendar.gregorian_seconds_to_datetime()
    |> NaiveDateTime.from_erl!()
  end

  defp gregorian_seconds(year, month, day) do
    :calendar.datetime_to_gregorian_seconds({{year, month, day}, {0, 0, 0}})
  end

  defp format_offset(seconds) do
    sign = if seconds < 0, do: "-", else: "+"
    total_minutes = div(abs(seconds), @seconds_per_minute)
    hours = div(total_minutes, 60)
    minutes = rem(total_minutes, 60)

    sign <>
      String.pad_leading(to_string(hours), 2, "0") <>
      String.pad_leading(to_string(minutes), 2, "0")
  end
end
