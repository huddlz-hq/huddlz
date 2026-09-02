defmodule HuddlzWeb.HuddlLive.FormHelpers do
  @moduledoc """
  Shared helpers for huddl and group create/edit forms.
  Provides date/time calculation, huddl-type visibility, and location helpers.
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

  def schedule_time_zone(form, selected_location, group) do
    case to_string(Phoenix.HTML.Form.input_value(form, :event_type) || "in_person") do
      "virtual" -> group.time_zone
      _physical_or_hybrid -> selected_location && selected_location.time_zone
    end
  end

  def ambiguous_time_label(_form, nil), do: nil

  def ambiguous_time_label(form, time_zone) do
    with {:ok, date} <- parse_date(Phoenix.HTML.Form.input_value(form, :date)),
         {:ok, time} <- parse_schedule_time(Phoenix.HTML.Form.input_value(form, :start_time)),
         {:ambiguous, earlier, _later} <- DateTime.new(date, time, time_zone) do
      "#{earlier.zone_abbr} (UTC#{format_offset(earlier.utc_offset + earlier.std_offset)})"
    else
      _not_ambiguous -> nil
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
      |> maybe_set_time_zone(location)
    end
  end

  defp maybe_set_time_zone(changeset, %{time_zone: time_zone}) when is_binary(time_zone) do
    Ash.Changeset.force_change_attribute(changeset, :time_zone, time_zone)
  end

  defp maybe_set_time_zone(changeset, _location), do: changeset

  @doc """
  Injects the location text into form params for group forms.
  Accepts a map with `:display_text` (from the autocomplete component).
  """
  def inject_group_location_param(params, nil), do: params

  def inject_group_location_param(params, %{
        display_text: text,
        latitude: latitude,
        longitude: longitude,
        time_zone: time_zone
      }) do
    params
    |> Map.put("location", text)
    |> Map.put("latitude", latitude)
    |> Map.put("longitude", longitude)
    |> Map.put("time_zone", time_zone)
  end

  @doc """
  Updates the group form with a resolved home location.
  """
  def apply_group_location_to_form(socket, location) when is_map(location) do
    current_params = socket.assigns.form.source.params || %{}
    updated_params = inject_group_location_param(current_params, location)
    form = AshPhoenix.Form.validate(socket.assigns.form.source, updated_params)
    assign(socket, :form, Phoenix.Component.to_form(form))
  end

  def apply_group_location_to_form(socket, nil) do
    current_params = socket.assigns.form.source.params || %{}

    form =
      AshPhoenix.Form.validate(
        socket.assigns.form.source,
        Map.put(current_params, "location", "")
      )

    assign(socket, :form, Phoenix.Component.to_form(form))
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

  defp parse_date(%Date{} = date), do: {:ok, date}
  defp parse_date(value) when is_binary(value), do: Date.from_iso8601(value)
  defp parse_date(_value), do: :error

  defp parse_schedule_time(%Time{} = time), do: {:ok, time}
  defp parse_schedule_time(value) when is_binary(value), do: parse_time(value)
  defp parse_schedule_time(_value), do: :error

  defp format_offset(seconds) do
    sign = if seconds < 0, do: "-", else: "+"
    seconds = abs(seconds)
    hours = div(seconds, 3600)
    minutes = seconds |> rem(3600) |> div(60)

    sign <>
      String.pad_leading(to_string(hours), 2, "0") <>
      ":" <> String.pad_leading(to_string(minutes), 2, "0")
  end
end
