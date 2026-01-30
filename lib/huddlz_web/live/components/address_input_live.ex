defmodule HuddlzWeb.Components.AddressInputLive do
  @moduledoc """
  A reusable LiveComponent for address input with autocomplete.

  Uses server-side geocoding via `Huddlz.Geocoding` to provide address
  suggestions as the user types. The API key stays on the server.

  ## Usage

      <.live_component
        module={HuddlzWeb.Components.AddressInputLive}
        id="user-address"
        label="Your Location"
        value={@address_display}
        on_select={fn address -> send(self(), {:address_selected, address}) end}
      />

  ## Props

    * `id` - Required. Unique identifier for the component.
    * `label` - Optional. Label text. Defaults to "Address".
    * `value` - Optional. Current formatted address to display.
    * `on_select` - Required. Callback function called with address data when selected.
    * `on_clear` - Optional. Callback function called when address is cleared.
    * `placeholder` - Optional. Input placeholder text.
    * `disabled` - Optional. Whether the input is disabled.

  ## Parent LiveView Setup

  The parent LiveView must handle geocoding messages:

      def handle_info({:do_search, component_id, query}, socket) do
        result = Huddlz.Geocoding.autocomplete(query)
        socket = AddressInputLive.handle_search_results(socket, component_id, result)
        {:noreply, socket}
      end

      def handle_info({:do_place_details, component_id, place_id}, socket) do
        result = Huddlz.Geocoding.place_details(place_id)
        socket = AddressInputLive.handle_place_details(socket, component_id, result)
        {:noreply, socket}
      end

  ## Callback Data

  The `on_select` callback receives a map with:

      %{
        formatted_address: "123 Main St, City, ST 12345, USA",
        latitude: 37.7749,
        longitude: -122.4194,
        city: "City",
        state: "ST",
        postal_code: "12345",
        country: "US",
        country_name: "United States",
        place_id: "ChIJ..."
      }
  """

  use HuddlzWeb, :live_component

  @min_query_length 3

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:query, "")
     |> assign(:suggestions, [])
     |> assign(:loading, false)
     |> assign(:show_dropdown, false)
     |> assign(:selected, false)
     |> assign(:error, nil)}
  end

  # Handle async search results from parent
  @impl true
  def update(%{__search_results__: suggestions}, socket) do
    {:ok,
     socket
     |> assign(:suggestions, suggestions)
     |> assign(:loading, false)
     |> assign(:show_dropdown, true)}
  end

  def update(%{__search_error__: _reason}, socket) do
    {:ok,
     socket
     |> assign(:loading, false)
     |> assign(:error, "Failed to search addresses. Please try again.")}
  end

  def update(%{__place_details__: address_data}, socket) do
    # Call the on_select callback with the address data
    socket.assigns.on_select.(address_data)

    {:ok,
     socket
     |> assign(:loading, false)
     |> assign(:query, address_data.formatted_address)}
  end

  def update(%{__details_error__: _reason}, socket) do
    {:ok,
     socket
     |> assign(:loading, false)
     |> assign(:error, "Failed to get address details. Please try again.")}
  end

  # Handle regular prop updates
  def update(assigns, socket) do
    socket =
      socket
      |> assign(:id, assigns.id)
      |> assign(:label, Map.get(assigns, :label, "Address"))
      |> assign(:value, Map.get(assigns, :value))
      |> assign(:on_select, assigns.on_select)
      |> assign(:on_clear, Map.get(assigns, :on_clear))
      |> assign(:placeholder, Map.get(assigns, :placeholder, "Start typing an address..."))
      |> assign(:disabled, Map.get(assigns, :disabled, false))

    # If value is set and query is empty, show the value
    socket =
      if assigns[:value] && socket.assigns.query == "" && !socket.assigns.selected do
        assign(socket, :query, assigns[:value] || "")
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} class="relative" phx-click-away="close_dropdown" phx-target={@myself}>
      <label class="fieldset-label mb-1">{@label}</label>

      <div class="relative">
        <input
          type="text"
          value={@query}
          placeholder={@placeholder}
          disabled={@disabled}
          class="w-full input pr-10"
          autocomplete="off"
          phx-debounce="300"
          phx-change="search"
          phx-focus="focus"
          phx-target={@myself}
          name="query"
        />

        <div class="absolute right-3 top-1/2 -translate-y-1/2 pointer-events-none">
          <%= if @loading do %>
            <span class="loading loading-spinner loading-sm text-base-content/50"></span>
          <% else %>
            <.icon name="hero-map-pin" class="h-5 w-5 text-base-content/50" />
          <% end %>
        </div>

        <%= if @query != "" && !@disabled do %>
          <button
            type="button"
            class="absolute right-10 top-1/2 -translate-y-1/2 p-1 hover:bg-base-200 rounded"
            phx-click="clear"
            phx-target={@myself}
          >
            <.icon name="hero-x-mark" class="h-4 w-4 text-base-content/50" />
          </button>
        <% end %>
      </div>

      <%= if @error do %>
        <p class="text-error text-sm mt-1">{@error}</p>
      <% end %>

      <%= if @show_dropdown && @suggestions != [] do %>
        <div class="absolute z-50 w-full mt-1 bg-base-100 border border-base-300 rounded-lg shadow-lg max-h-60 overflow-y-auto">
          <%= for suggestion <- @suggestions do %>
            <button
              type="button"
              class="w-full text-left px-4 py-3 hover:bg-base-200 focus:bg-base-200 focus:outline-none border-b border-base-200 last:border-b-0 transition-colors"
              phx-click="select"
              phx-value-place-id={suggestion.place_id}
              phx-value-description={suggestion.description}
              phx-target={@myself}
            >
              <div class="flex items-start gap-3">
                <.icon name="hero-map-pin" class="h-5 w-5 text-base-content/50 mt-0.5 flex-shrink-0" />
                <span class="text-sm">{suggestion.description}</span>
              </div>
            </button>
          <% end %>
        </div>
      <% end %>

      <%= if @show_dropdown && @suggestions == [] && @query != "" && String.length(@query) >= @min_query_length && !@loading do %>
        <div class="absolute z-50 w-full mt-1 bg-base-100 border border-base-300 rounded-lg shadow-lg">
          <div class="px-4 py-3 text-sm text-base-content/70">
            No addresses found
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    socket = assign(socket, :query, query)

    if String.length(query) >= @min_query_length do
      send(self(), {:do_search, socket.assigns.id, query})

      {:noreply,
       socket
       |> assign(:loading, true)
       |> assign(:show_dropdown, true)
       |> assign(:selected, false)
       |> assign(:error, nil)}
    else
      {:noreply,
       socket
       |> assign(:suggestions, [])
       |> assign(:show_dropdown, false)
       |> assign(:loading, false)}
    end
  end

  def handle_event("focus", _params, socket) do
    show = socket.assigns.suggestions != [] && !socket.assigns.selected
    {:noreply, assign(socket, :show_dropdown, show)}
  end

  def handle_event("close_dropdown", _params, socket) do
    {:noreply, assign(socket, :show_dropdown, false)}
  end

  def handle_event("select", %{"place-id" => place_id, "description" => description}, socket) do
    send(self(), {:do_place_details, socket.assigns.id, place_id})

    {:noreply,
     socket
     |> assign(:query, description)
     |> assign(:loading, true)
     |> assign(:show_dropdown, false)
     |> assign(:selected, true)}
  end

  def handle_event("clear", _params, socket) do
    if socket.assigns.on_clear do
      socket.assigns.on_clear.()
    end

    {:noreply,
     socket
     |> assign(:query, "")
     |> assign(:suggestions, [])
     |> assign(:show_dropdown, false)
     |> assign(:selected, false)
     |> assign(:error, nil)}
  end

  # Public helpers for parent LiveView to handle geocoding messages

  @doc """
  Handle search results from Huddlz.Geocoding.autocomplete/2.

  Call this from your LiveView's handle_info:

      def handle_info({:do_search, component_id, query}, socket) do
        result = Huddlz.Geocoding.autocomplete(query)
        socket = AddressInputLive.handle_search_results(socket, component_id, result)
        {:noreply, socket}
      end
  """
  def handle_search_results(socket, component_id, {:ok, suggestions}) do
    send_update(__MODULE__, id: component_id, __search_results__: suggestions)
    socket
  end

  def handle_search_results(socket, component_id, {:error, _reason}) do
    send_update(__MODULE__, id: component_id, __search_error__: true)
    socket
  end

  @doc """
  Handle place details from Huddlz.Geocoding.place_details/1.

  Call this from your LiveView's handle_info:

      def handle_info({:do_place_details, component_id, place_id}, socket) do
        result = Huddlz.Geocoding.place_details(place_id)
        socket = AddressInputLive.handle_place_details(socket, component_id, result)
        {:noreply, socket}
      end
  """
  def handle_place_details(socket, component_id, {:ok, address_data}) do
    send_update(__MODULE__, id: component_id, __place_details__: address_data)
    socket
  end

  def handle_place_details(socket, component_id, {:error, _reason}) do
    send_update(__MODULE__, id: component_id, __details_error__: true)
    socket
  end
end
