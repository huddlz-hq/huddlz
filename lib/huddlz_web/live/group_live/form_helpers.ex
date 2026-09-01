defmodule HuddlzWeb.GroupLive.FormHelpers do
  @moduledoc false

  use Phoenix.Component

  def inject_group_location_param(params, nil), do: params

  def inject_group_location_param(params, %{display_text: text}) do
    Map.put(params, "location", text)
  end

  def apply_group_location_to_form(socket, text) do
    current_params = socket.assigns.form.source.params || %{}
    updated_params = Map.put(current_params, "location", text)
    form = AshPhoenix.Form.validate(socket.assigns.form.source, updated_params)
    assign(socket, :form, Phoenix.Component.to_form(form))
  end

  def resolve_group_location_time_zone(socket, %{latitude: latitude, longitude: longitude}) do
    case Huddlz.Communities.resolve_group_time_zone(latitude, longitude,
           actor: socket.assigns.current_user
         ) do
      {:ok, time_zone} ->
        socket
        |> apply_group_time_zone_to_form(time_zone)
        |> assign(:group_time_zone_error, nil)

      {:error, _reason} ->
        socket
        |> apply_group_time_zone_to_form("")
        |> assign(:group_time_zone_error, "Choose a valid time zone for this city")
    end
  end

  def clear_group_time_zone_error(socket, %{"time_zone" => time_zone}) do
    if Huddlz.TimeZone.canonical?(time_zone) do
      assign(socket, :group_time_zone_error, nil)
    else
      socket
    end
  end

  def clear_group_time_zone_error(socket, _params), do: socket

  defp apply_group_time_zone_to_form(socket, time_zone) do
    current_params = socket.assigns.form.source.params || %{}

    form =
      socket.assigns.form.source
      |> AshPhoenix.Form.validate(Map.put(current_params, "time_zone", time_zone))
      |> Phoenix.Component.to_form()

    assign(socket, :form, form)
  end
end
