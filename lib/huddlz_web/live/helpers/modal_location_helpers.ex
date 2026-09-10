defmodule HuddlzWeb.Live.Helpers.ModalLocationHelpers do
  @moduledoc """
  Shared state handling for the "Select a location" modal used in the
  huddl and group new/edit/locations LiveViews.

  The modal owns the following socket assigns:

    * `:modal_location_address` — full display text (nil when empty)
    * `:modal_location_lat` / `:modal_location_lng` — geocoded coordinates
    * `:modal_location_time_zone` — canonical IANA time zone
    * `:modal_location_name` — short name (bound to the name input)
    * `:modal_location_form` — Ash form carrying saved-location validation errors
  """

  import Phoenix.Component, only: [assign: 2, to_form: 1]

  alias AshPhoenix.Form
  alias Huddlz.Communities
  alias Huddlz.Communities.GroupLocation

  @doc "Initialize all modal location assigns to their empty values."
  def init(socket) do
    assign(socket,
      modal_location_address: nil,
      modal_location_lat: nil,
      modal_location_lng: nil,
      modal_location_time_zone: nil,
      modal_location_name: "",
      modal_location_form: to_form(Form.for_create(GroupLocation, :create, domain: Communities))
    )
  end

  @doc "Reset the modal location assigns to their empty values."
  def clear(socket), do: init(socket)

  @doc "Submit the saved location with trusted address data and the entered name."
  def submit(socket, group_id, params) do
    params = %{
      "name" => Map.get(params, "location_name", socket.assigns.modal_location_name),
      "address" => socket.assigns.modal_location_address,
      "latitude" => socket.assigns.modal_location_lat,
      "longitude" => socket.assigns.modal_location_lng,
      "time_zone" => socket.assigns.modal_location_time_zone,
      "group_id" => group_id
    }

    GroupLocation
    |> Form.for_create(:create, domain: Communities, actor: socket.assigns.current_user)
    |> Form.submit(params: params)
  end

  @doc """
  Apply a location-selected payload from the LocationAutocomplete component.

  The payload is expected to be a map with:

    * `:display_text` — full address
    * `:main_text` — primary name (e.g. "Coffee Shop")
    * `:latitude` / `:longitude`
    * `:time_zone` — canonical IANA time zone
  """
  def apply_selected(socket, %{} = payload) do
    assign(socket,
      modal_location_address: Map.get(payload, :display_text),
      modal_location_lat: Map.get(payload, :latitude),
      modal_location_lng: Map.get(payload, :longitude),
      modal_location_time_zone: Map.get(payload, :time_zone),
      modal_location_name: Map.get(payload, :main_text) || ""
    )
  end
end
