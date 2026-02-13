defmodule HuddlzWeb.HuddlLive.FormHelpers do
  @moduledoc """
  Shared helpers for huddl create/edit forms.
  Provides date/time calculation and event type visibility logic.
  """
  import Phoenix.Component, only: [assign: 3]

  def update_calculated_end_time(socket, params) do
    case {params["date"], params["start_time"], params["duration_minutes"]} do
      {d, t, dur} when d != "" and t != "" and dur != "" ->
        with {:ok, date} <- Date.from_iso8601(d),
             {:ok, time} <- parse_time(t),
             {duration, ""} <- Integer.parse(dur) do
          assign(socket, :calculated_end_time, calculate_end_time(date, time, duration))
        else
          _ -> socket
        end

      _ ->
        socket
    end
  end

  def update_event_type_visibility(socket, params) do
    event_type = Map.get(params, "event_type", "in_person")

    socket
    |> assign(:show_physical_location, event_type in ["in_person", "hybrid"])
    |> assign(:show_virtual_link, event_type in ["virtual", "hybrid"])
  end

  def calculate_end_time(date, time, duration_minutes) do
    case DateTime.new(date, time, "Etc/UTC") do
      {:ok, starts_at} ->
        ends_at = DateTime.add(starts_at, duration_minutes, :minute)

        if Date.compare(DateTime.to_date(ends_at), date) == :eq do
          Calendar.strftime(ends_at, "%I:%M %p")
        else
          Calendar.strftime(ends_at, "%I:%M %p (next day)")
        end

      _ ->
        nil
    end
  end

  def parse_time(time_str) do
    case String.split(time_str, ":") do
      [hour_str, minute_str] ->
        with {hour, ""} <- Integer.parse(hour_str),
             {minute, ""} <- Integer.parse(minute_str) do
          Time.new(hour, minute, 0)
        end

      [hour_str, minute_str, _second_str] ->
        with {hour, ""} <- Integer.parse(hour_str),
             {minute, ""} <- Integer.parse(minute_str) do
          Time.new(hour, minute, 0)
        end

      _ ->
        :error
    end
  end
end
