defmodule HuddlzWeb.Live.SavedLocationPicker do
  @moduledoc """
  A LiveComponent for picking from saved group locations.

  Provides a searchable dropdown of saved locations and an "Add new address" link.
  Notifies the parent via messages:
  - `{:saved_location_selected, id, %GroupLocation{}}`
  - `{:saved_location_cleared, id}`
  """
  use HuddlzWeb, :live_component

  attr :id, :string, required: true
  attr :group_locations, :list, required: true
  attr :selected_location, :any, default: nil
  attr :new_location_path, :string, required: true

  def mount(socket) do
    {:ok,
     assign(socket,
       search_text: "",
       filtered_locations: [],
       show_dropdown: false,
       group_locations: [],
       selected_location: nil,
       previous_location: nil,
       initialized: false
     )}
  end

  def update(assigns, socket) do
    socket = assign(socket, Map.drop(assigns, [:selected_location, :group_locations]))

    socket =
      if socket.assigns.initialized do
        socket
        |> assign(:group_locations, assigns.group_locations)
        |> maybe_update_selection(assigns)
      else
        socket
        |> assign(:group_locations, assigns.group_locations)
        |> assign(:selected_location, assigns.selected_location)
        |> assign(:filtered_locations, assigns.group_locations)
        |> assign(:initialized, true)
      end

    {:ok, socket}
  end

  defp maybe_update_selection(socket, assigns) do
    new_selection = assigns[:selected_location]

    if new_selection != socket.assigns.selected_location do
      # Parent assigns are canonical. If the parent swaps to a fresh selection
      # (e.g., after the "Add new address" modal saves), drop any stashed
      # `previous_location` so the dismiss handler can't quietly restore the
      # pre-edit pick on the next click-away.
      socket
      |> assign(:selected_location, new_selection)
      |> assign(:previous_location, nil)
    else
      socket
    end
  end

  def render(assigns) do
    ~H"""
    <div
      id={@id}
      class="form-row filter-location-wrap"
      phx-click-away="dismiss"
      phx-target={@myself}
    >
      <label class="form-label" for={"#{@id}-input"}>Physical Location</label>

      <%= if @selected_location do %>
        <div class="location-display" data-testid="saved-location-selected">
          <div class="location-current">
            <svg
              width="16"
              height="16"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="1.8"
              stroke-linecap="round"
              stroke-linejoin="round"
              aria-hidden="true"
            >
              <path d="M12 22s7-7.6 7-13a7 7 0 0 0-14 0c0 5.4 7 13 7 13z" />
              <circle cx="12" cy="9" r="2.5" />
            </svg>
            <span data-testid="saved-location-display">
              {@selected_location.name || @selected_location.address}
            </span>
          </div>
          <div class="location-actions">
            <button
              type="button"
              class="btn-secondary"
              phx-click="edit"
              phx-target={@myself}
              data-testid="saved-location-change"
            >
              Change address…
            </button>
            <.link patch={@new_location_path} class="btn-secondary">
              Add new address
            </.link>
          </div>
        </div>
      <% else %>
        <div class="location-control">
          <input
            type="text"
            id={"#{@id}-input"}
            class="form-input"
            value={@search_text}
            placeholder={
              if @group_locations == [],
                do: "No saved locations yet — add one below",
                else: "Search saved locations..."
            }
            phx-change="search"
            phx-target={@myself}
            phx-debounce="100"
            phx-focus="show_dropdown"
            name={"#{@id}_search"}
            autocomplete="off"
            data-testid="saved-location-input"
            role="combobox"
            aria-expanded={to_string(@show_dropdown && @filtered_locations != [])}
            aria-controls={"#{@id}-listbox"}
            disabled={@group_locations == []}
          />
          <button
            :if={@previous_location}
            type="button"
            class="form-clear"
            phx-click="cancel_edit"
            phx-target={@myself}
            aria-label="Cancel"
          >
            ×
          </button>
        </div>

        <div
          :if={@show_dropdown && @filtered_locations != []}
          id={"#{@id}-listbox"}
          role="listbox"
          class="filter-location-listbox"
          style="min-width: 100%"
        >
          <button
            :for={loc <- @filtered_locations}
            type="button"
            phx-click="select"
            phx-value-id={loc.id}
            phx-target={@myself}
            class="filter-location-option"
          >
            <span class="opt-main">{loc.name || loc.address}</span>
            <span :if={loc.name} class="opt-secondary">{loc.address}</span>
          </button>
        </div>

        <p
          :if={
            @show_dropdown && @filtered_locations == [] && @search_text != "" &&
              @group_locations != []
          }
          class="filter-location-listbox empty"
          style="min-width: 100%"
        >
          No matching locations found
        </p>

        <.link patch={@new_location_path} class="btn-secondary saved-location-add">
          Add new address
        </.link>
      <% end %>
    </div>
    """
  end

  def handle_event("search", params, socket) do
    text = params[socket.assigns.id <> "_search"] || ""
    filtered = filter_locations(socket.assigns.group_locations, text)

    {:noreply,
     assign(socket,
       search_text: text,
       filtered_locations: filtered,
       show_dropdown: true
     )}
  end

  def handle_event("show_dropdown", _params, socket) do
    filtered = filter_locations(socket.assigns.group_locations, socket.assigns.search_text)
    {:noreply, assign(socket, show_dropdown: true, filtered_locations: filtered)}
  end

  def handle_event("select", %{"id" => id}, socket) do
    location = Enum.find(socket.assigns.group_locations, &(&1.id == id))

    if location do
      send(self(), {:saved_location_selected, socket.assigns.id, location})

      {:noreply,
       assign(socket,
         selected_location: location,
         previous_location: nil,
         show_dropdown: false,
         search_text: ""
       )}
    else
      {:noreply, socket}
    end
  end

  def handle_event("edit", _params, socket) do
    {:noreply,
     assign(socket,
       previous_location: socket.assigns.selected_location,
       selected_location: nil,
       search_text: "",
       filtered_locations: socket.assigns.group_locations,
       show_dropdown: true
     )}
  end

  def handle_event("clear", _params, socket) do
    send(self(), {:saved_location_cleared, socket.assigns.id})

    {:noreply,
     assign(socket,
       selected_location: nil,
       previous_location: nil,
       search_text: "",
       show_dropdown: false
     )}
  end

  def handle_event("cancel_edit", _params, socket) do
    location = socket.assigns.previous_location

    if location do
      send(self(), {:saved_location_selected, socket.assigns.id, location})

      {:noreply,
       assign(socket,
         selected_location: location,
         previous_location: nil,
         show_dropdown: false,
         search_text: ""
       )}
    else
      {:noreply, socket}
    end
  end

  def handle_event("dismiss", _params, socket) do
    if socket.assigns.previous_location do
      # Clicking away restores the previous selection
      location = socket.assigns.previous_location
      send(self(), {:saved_location_selected, socket.assigns.id, location})

      {:noreply,
       assign(socket,
         selected_location: location,
         previous_location: nil,
         show_dropdown: false,
         search_text: ""
       )}
    else
      {:noreply, assign(socket, show_dropdown: false)}
    end
  end

  defp filter_locations(locations, ""), do: locations

  defp filter_locations(locations, text) do
    text_down = String.downcase(text)

    Enum.filter(locations, fn loc ->
      (loc.name && String.contains?(String.downcase(loc.name), text_down)) ||
        String.contains?(String.downcase(loc.address), text_down)
    end)
  end
end
