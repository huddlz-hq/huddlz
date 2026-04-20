defmodule HuddlzWeb.Live.Helpers.ModalLocationHelpers do
  @moduledoc """
  Shared state handling for the "Select a location" modal used in the
  huddl and group new/edit/locations LiveViews.

  The modal owns four socket assigns:

    * `:modal_location_address` — full display text (nil when empty)
    * `:modal_location_lat` / `:modal_location_lng` — geocoded coordinates
    * `:modal_location_name` — short name (bound to the name input)
  """

  import Phoenix.Component, only: [assign: 2]

  @doc "Initialize all modal location assigns to their empty values."
  def init(socket) do
    assign(socket,
      modal_location_address: nil,
      modal_location_lat: nil,
      modal_location_lng: nil,
      modal_location_name: ""
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
    assign(socket,
      modal_location_address: Map.get(payload, :display_text),
      modal_location_lat: Map.get(payload, :latitude),
      modal_location_lng: Map.get(payload, :longitude),
      modal_location_name: Map.get(payload, :main_text) || ""
    )
  end
end
