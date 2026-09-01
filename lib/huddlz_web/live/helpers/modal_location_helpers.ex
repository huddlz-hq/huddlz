defmodule HuddlzWeb.Live.Helpers.ModalLocationHelpers do
  @moduledoc """
  Shared state handling for the "Select a location" modal used in the
  huddl and group new/edit/locations LiveViews.

  The modal owns location and time-zone assigns:

    * `:modal_location_address` — full display text (nil when empty)
    * `:modal_location_lat` / `:modal_location_lng` — geocoded coordinates
    * `:modal_location_name` — short name (bound to the name input)
    * `:modal_location_time_zone` — resolved or manually selected IANA zone
    * `:modal_location_time_zone_error` — repair guidance after resolution failure
  """

  import Phoenix.Component, only: [assign: 2]

  @time_zone_error "Choose an address whose time zone can be resolved"

  @doc "Initialize all modal location assigns to their empty values."
  def init(socket) do
    assign(socket,
      modal_location_address: nil,
      modal_location_lat: nil,
      modal_location_lng: nil,
      modal_location_name: "",
      modal_location_time_zone: nil,
      modal_location_time_zone_error: nil
    )
  end

  @doc "Reset the modal location assigns to their empty values."
  def clear(socket), do: init(socket)

  @doc """
  Apply a location-selected payload from the LocationAutocomplete component.

  The payload is expected to be a map with:

    * `:display_text` — full address
    * `:main_text` — primary name (e.g. "Coffee Shop")
    * `:latitude` / `:longitude`
  """
  def apply_selected(socket, %{} = payload) do
    latitude = Map.get(payload, :latitude)
    longitude = Map.get(payload, :longitude)

    socket =
      assign(socket,
        modal_location_address: Map.get(payload, :display_text),
        modal_location_lat: latitude,
        modal_location_lng: longitude,
        modal_location_name: Map.get(payload, :main_text) || ""
      )

    resolve_time_zone(socket, latitude, longitude)
  end

  def apply_form_changes(socket, params) do
    socket
    |> maybe_assign_name(params)
  end

  def require_time_zone_choice(socket) do
    assign(socket, modal_location_time_zone_error: @time_zone_error)
  end

  defp maybe_assign_name(socket, %{"location_name" => name}),
    do: assign(socket, modal_location_name: name)

  defp maybe_assign_name(socket, _params), do: socket

  defp resolve_time_zone(socket, latitude, longitude) do
    case Huddlz.LocationTimeZone.resolve(latitude, longitude) do
      {:ok, time_zone} ->
        assign(socket,
          modal_location_time_zone: time_zone,
          modal_location_time_zone_error: nil
        )

      {:error, _reason} ->
        socket
        |> assign(modal_location_time_zone: "")
        |> require_time_zone_choice()
    end
  end
end
