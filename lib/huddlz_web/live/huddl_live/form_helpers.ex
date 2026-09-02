defmodule HuddlzWeb.HuddlLive.FormHelpers do
  @moduledoc """
  Shared helpers for huddl and group create/edit forms.
  Provides date/time calculation, huddl-type visibility, and location helpers.
  """
  import Phoenix.Component, only: [assign: 3]

  alias Huddlz.Scheduling.LocalDateTime

  def device_time_zone(socket) do
    socket
    |> Phoenix.LiveView.get_connect_params()
    |> Huddlz.TimeZone.from_connect_params()
  end

  def schedule_datetime(datetime, nil), do: datetime

  def schedule_datetime(datetime, time_zone) do
    DateTime.shift_zone!(datetime, time_zone)
  end

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

  def update_daylight_saving_resolution(socket, params) do
    resolution =
      with {:ok, date} <- Date.from_iso8601(params["date"] || ""),
           {:ok, time} <- parse_time(params["start_time"] || ""),
           time_zone when is_binary(time_zone) and time_zone != "" <- params["time_zone"],
           occurrence <- occurrence(params["ambiguous_time_occurrence"]),
           {:ok, resolution} <- LocalDateTime.resolve(date, time, time_zone, occurrence) do
        resolution
      else
        _ -> nil
      end

    assign(socket, :daylight_saving_resolution, resolution)
  end

  def update_event_type_visibility(socket, params) do
    event_type = Map.get(params, "event_type", "in_person")

    socket
    |> assign(:show_physical_location, event_type in ["in_person", "hybrid"])
    |> assign(:show_virtual_link, event_type in ["virtual", "hybrid"])
    |> assign(:show_huddl_time_zone, event_type == "virtual")
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

  def apply_saved_location_to_form(socket, location) do
    current_params = socket.assigns.form.source.params || %{}

    updated_params =
      current_params
      |> Map.put("physical_location", location.address)
      |> Map.put("group_location_id", location.id)

    form = AshPhoenix.Form.validate(socket.assigns.form, updated_params)

    socket
    |> assign(:selected_location, location)
    |> assign(:form, Phoenix.Component.to_form(form))
  end

  def clear_saved_location(socket) do
    current_params = socket.assigns.form.source.params || %{}

    updated_params =
      current_params
      |> Map.put("physical_location", "")
      |> Map.put("group_location_id", nil)

    form = AshPhoenix.Form.validate(socket.assigns.form, updated_params)

    socket
    |> assign(:selected_location, nil)
    |> assign(:form, Phoenix.Component.to_form(form))
  end

  def inject_saved_location_params(params, nil), do: Map.put(params, "group_location_id", nil)

  def inject_saved_location_params(params, location) do
    params
    |> Map.put("physical_location", location.address)
    |> Map.put("group_location_id", location.id)
  end

  @doc """
  Ensures the "physical_location" key is present in the params so
  `Phoenix.Component.used_input?/1` treats the picker-backed field as used
  and its validation errors display. The saved-location picker renders no
  client-side input, so the browser never sends this key on its own. Falls
  back to the form's current value to avoid clearing an existing location
  on update.

  Call on every submit. On validate, use `mark_location_used_after_submit/2`
  so errors stay hidden while the user is still filling in the form but
  remain visible while fixing a failed submit.
  """
  def mark_location_used(params, form) do
    Map.put_new(params, "physical_location", current_location_value(form))
  end

  def mark_location_used_after_submit(params, form) do
    if form.source.submitted_once? do
      mark_location_used(params, form)
    else
      params
    end
  end

  defp current_location_value(form) do
    case Phoenix.HTML.Form.input_value(form, :physical_location) do
      nil -> ""
      value -> to_string(value)
    end
  end

  @doc """
  Returns a `before_submit` function that applies pre-existing coordinates
  directly to the changeset. Used with `AshPhoenix.Form.submit/2`'s
  `:before_submit` option, which runs after `for_create`/`for_update`
  (i.e., after Ash resource changes have already executed).
  """
  def prepare_source_with_coordinates(nil), do: & &1

  def prepare_source_with_coordinates(location) when is_map(location) do
    fn changeset ->
      changeset
      |> Ash.Changeset.force_change_attribute(:latitude, location.latitude)
      |> Ash.Changeset.force_change_attribute(:longitude, location.longitude)
    end
  end

  def load_group_locations(group_id, user) do
    case Huddlz.Communities.list_group_locations(group_id, actor: user) do
      {:ok, locations} -> locations
      _ -> []
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

  defp occurrence("later"), do: :later
  defp occurrence(_occurrence), do: :earlier
end
