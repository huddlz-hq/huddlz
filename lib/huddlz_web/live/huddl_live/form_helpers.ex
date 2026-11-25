defmodule HuddlzWeb.HuddlLive.FormHelpers do
  @moduledoc """
  Shared helpers for huddl and group create/edit forms.
  Provides huddl-type visibility and location helpers.
  """
  import Phoenix.Component, only: [assign: 3]

  def update_event_type_visibility(socket, params) do
    event_type = Map.get(params, "event_type", "in_person")

    socket
    |> assign(:show_physical_location, event_type in ["in_person", "hybrid"])
    |> assign(:show_virtual_link, event_type in ["virtual", "hybrid"])
  end

  def apply_saved_location_to_form(socket, location) do
    current_params = socket.assigns.form.source.params || %{}

    updated_params = Map.put(current_params, "group_location_id", location.id)
    form = AshPhoenix.Form.validate(socket.assigns.form, updated_params)

    socket
    |> assign(:selected_location, location)
    |> assign(:form, Phoenix.Component.to_form(form))
  end

  def clear_saved_location(socket) do
    current_params = socket.assigns.form.source.params || %{}

    updated_params = Map.put(current_params, "group_location_id", nil)
    form = AshPhoenix.Form.validate(socket.assigns.form, updated_params)

    socket
    |> assign(:selected_location, nil)
    |> assign(:form, Phoenix.Component.to_form(form))
  end

  @doc """
  Puts the chosen address book location into the params. The picker renders no
  input of its own, so the key is added by hand: on save it is always present,
  and on validate only once a submit has failed, so the field counts as used
  (`Phoenix.Component.used_input?/1`) and its errors display at the right time.
  """
  def inject_saved_location_params(params, location, form, mode \\ :validate)

  def inject_saved_location_params(params, %{id: id}, _form, _mode),
    do: Map.put(params, "group_location_id", id)

  def inject_saved_location_params(params, nil, form, mode) do
    if mode == :save or form.source.submitted_once? do
      Map.put(params, "group_location_id", nil)
    else
      params
    end
  end

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
  Marks the group location as untouched while it is blank and nothing has
  been picked. Its value travels in a hidden input, which LiveView never
  reports as unused, so without this the "is required" error would show
  on the first change to any other field. Submitting sends no marker, so
  the error still shows then.
  """
  def mark_untouched_group_location(%{"location" => ""} = params, nil),
    do: Map.put(params, "_unused_location", "")

  def mark_untouched_group_location(params, _selected), do: params

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
end
