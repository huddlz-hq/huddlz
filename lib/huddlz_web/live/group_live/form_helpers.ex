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

  def apply_new_group_location_to_form(socket, location_data) do
    current_params = socket.assigns.form.source.params || %{}
    updated_params = Map.put(current_params, "location", location_data.display_text)

    form =
      Huddlz.Communities.Group
      |> AshPhoenix.Form.for_create(:create_group,
        actor: socket.assigns.current_user,
        forms: [auto?: true],
        params: updated_params,
        prepare_source: fn changeset ->
          changeset
          |> Ash.Changeset.set_argument(:provided_latitude, location_data.latitude)
          |> Ash.Changeset.set_argument(:provided_longitude, location_data.longitude)
        end
      )
      |> Phoenix.Component.to_form()

    assign(socket, :form, form)
  end

  def resolve_group_location_time_zone(socket, %{latitude: latitude, longitude: longitude}) do
    case Huddlz.Communities.resolve_group_time_zone(latitude, longitude,
           actor: socket.assigns.current_user
         ) do
      {:ok, time_zone} ->
        assign(socket,
          resolved_group_time_zone: time_zone,
          group_time_zone_error: nil
        )

      {:error, _reason} ->
        assign(socket,
          resolved_group_time_zone: nil,
          group_time_zone_error: "Choose a city whose time zone can be resolved"
        )
    end
  end
end
