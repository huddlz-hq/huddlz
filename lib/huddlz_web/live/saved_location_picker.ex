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
      assign(socket, :selected_location, new_selection)
    else
      socket
    end
  end

  def render(assigns) do
    ~H"""
    <div id={@id} class="relative" phx-click-away="dismiss" phx-target={@myself}>
      <label class="mono-label text-primary/70 mb-1.5 block">Physical Location</label>

      <%= if @selected_location do %>
        <div class="relative" data-testid="saved-location-selected">
          <div class="flex items-center h-10 pl-6 pr-6 border-0 border-b border-primary/50 bg-transparent group">
            <.icon
              name="hero-map-pin"
              class="absolute left-0 top-1/2 -translate-y-1/2 w-4 h-4 text-primary"
            />
            <div
              phx-click="clear"
              phx-target={@myself}
              class="flex items-center flex-1 min-w-0 cursor-pointer"
              role="button"
              aria-label="Change location"
            >
              <span
                class="text-sm text-base-content truncate flex-1"
                data-testid="saved-location-display"
              >
                {@selected_location.name || @selected_location.address}
              </span>
              <span
                :if={@selected_location.name}
                class="text-xs text-base-content/40 ml-2 truncate hidden sm:inline"
              >
                {@selected_location.address}
              </span>
              <.icon
                name="hero-pencil"
                class="w-3.5 h-3.5 ml-2 text-transparent group-hover:text-primary/50 transition-colors"
              />
            </div>
          </div>
        </div>
      <% else %>
        <div class="relative">
          <.icon
            name="hero-map-pin"
            class="absolute left-0 top-1/2 -translate-y-1/2 w-4 h-4 text-base-content/40"
          />
          <input
            type="text"
            id={"#{@id}-input"}
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
            class={[
              "w-full h-10 pl-6 pr-6 border-0 border-b border-base-300 bg-transparent",
              "focus:border-primary focus:ring-0 focus:outline-none text-base-content text-sm",
              @group_locations == [] && "opacity-50 cursor-not-allowed"
            ]}
          />

          <div
            :if={@show_dropdown && @filtered_locations != []}
            id={"#{@id}-listbox"}
            role="listbox"
            class="absolute z-50 w-full mt-1 border border-base-300 bg-base-200 max-h-60 overflow-y-auto shadow-[0_4px_20px_oklch(75%_0.18_195/0.15)]"
          >
            <button
              :for={loc <- @filtered_locations}
              type="button"
              phx-click="select"
              phx-value-id={loc.id}
              phx-target={@myself}
              class="w-full text-left px-4 py-3 border-b border-base-300 last:border-b-0 cursor-pointer border-l-2 border-l-transparent hover:bg-primary/20 hover:border-l-primary"
            >
              <span class="font-medium text-base-content">{loc.name || loc.address}</span>
              <span :if={loc.name} class="text-sm text-base-content/50 ml-1">{loc.address}</span>
            </button>
          </div>

          <p
            :if={
              @show_dropdown && @filtered_locations == [] && @search_text != "" &&
                @group_locations != []
            }
            class="absolute z-50 w-full mt-1 px-4 py-3 border border-base-300 bg-base-200 text-sm text-base-content/50 shadow-[0_4px_20px_oklch(75%_0.18_195/0.15)]"
          >
            No matching locations found
          </p>
        </div>
      <% end %>

      <.link
        patch={@new_location_path}
        class="mt-2 inline-flex items-center gap-1.5 text-sm text-primary/70 hover:text-primary transition-colors"
      >
        <.icon name="hero-plus" class="h-3.5 w-3.5" /> Add new address
      </.link>
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
         show_dropdown: false,
         search_text: ""
       )}
    else
      {:noreply, socket}
    end
  end

  def handle_event("clear", _params, socket) do
    send(self(), {:saved_location_cleared, socket.assigns.id})

    {:noreply,
     assign(socket,
       selected_location: nil,
       search_text: "",
       show_dropdown: false
     )}
  end

  def handle_event("dismiss", _params, socket) do
    {:noreply, assign(socket, show_dropdown: false)}
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
