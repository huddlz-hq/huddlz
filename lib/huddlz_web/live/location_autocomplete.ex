defmodule HuddlzWeb.Live.LocationAutocomplete do
  @moduledoc """
  A reusable stateful LiveComponent for location autocomplete.

  Uses a two-state UI pattern:
  - **Searching**: Text input visible, user types, suggestions dropdown appears
  - **Selected**: Static display of selected location with edit/clear buttons

  Manages all autocomplete state internally and notifies the parent via messages:
  - `{:location_selected, id, %{place_id, display_text, main_text, latitude, longitude}}`
  - `{:location_cleared, id}`
  """
  use HuddlzWeb, :live_component

  attr :id, :string, required: true
  attr :field_name, :string, default: nil
  attr :value, :string, default: nil
  attr :latitude, :float, default: nil
  attr :longitude, :float, default: nil
  attr :label, :string, default: nil
  attr :label_class, :string, default: "mono-label text-primary/70 mb-1.5 block"
  attr :placeholder, :string, default: "Search for a city..."
  attr :types, :list, default: ["locality"]
  attr :show_clear, :boolean, default: true
  attr :fetch_coordinates, :boolean, default: true

  def mount(socket) do
    {:ok,
     assign(socket,
       # Configuration defaults (overridden by parent via update/2)
       field_name: nil,
       label: nil,
       label_class: "mono-label text-primary/70 mb-1.5 block",
       placeholder: "Search for a city...",
       types: ["locality"],
       show_clear: true,
       fetch_coordinates: true,
       # Internal state
       search_text: "",
       suggestions: [],
       show_suggestions: false,
       suggestion_index: -1,
       loading: false,
       error: nil,
       session_token: Ecto.UUID.generate(),
       selected: false,
       selected_text: nil,
       selected_place_id: nil,
       selected_lat: nil,
       selected_lng: nil,
       selected_main_text: nil,
       initialized: false
     )}
  end

  def update(assigns, socket) do
    socket = assign(socket, Map.drop(assigns, [:value, :latitude, :longitude]))

    socket =
      if socket.assigns.initialized do
        maybe_reset(socket, assigns)
      else
        initialize(socket, assigns)
      end

    {:ok, socket}
  end

  defp initialize(socket, assigns) do
    value = assigns[:value]
    lat = assigns[:latitude]
    lng = assigns[:longitude]

    cond do
      value && value != "" && lat && lng ->
        assign(socket,
          selected: true,
          selected_text: value,
          selected_lat: lat,
          selected_lng: lng,
          initialized: true
        )

      value && value != "" ->
        assign(socket,
          search_text: value,
          initialized: true
        )

      true ->
        assign(socket, initialized: true)
    end
  end

  defp maybe_reset(socket, assigns) do
    value = assigns[:value]

    if is_nil(value) && socket.assigns.selected do
      reset_state(socket)
    else
      socket
    end
  end

  def render(assigns) do
    ~H"""
    <div
      id={@id}
      class="relative"
      phx-click-away="dismiss"
      phx-target={@myself}
      phx-hook="LocationAutocomplete"
      data-has-highlight={to_string(@suggestion_index >= 0)}
    >
      <label :if={@label} for={"#{@id}-input"} class={@label_class}>
        {@label}
      </label>

      <%!-- SELECTED STATE --%>
      <div :if={@selected} class="relative" data-testid="location-selected">
        <input :if={@field_name} type="hidden" name={@field_name} value={@selected_text} />
        <div class="flex items-center h-10 pl-6 pr-6 border-0 border-b border-primary/50 bg-transparent group">
          <.icon
            name="hero-map-pin"
            class="absolute left-0 top-1/2 -translate-y-1/2 w-4 h-4 text-primary"
          />
          <div
            :if={!@loading}
            phx-click="edit"
            phx-target={@myself}
            class="flex items-center flex-1 min-w-0 cursor-pointer"
            role="button"
            aria-label="Edit location"
          >
            <span class="text-sm text-base-content truncate flex-1" data-testid="location-display">
              {@selected_text}
            </span>
            <.icon
              name="hero-pencil"
              class="w-3.5 h-3.5 ml-2 text-transparent group-hover:text-primary/50 transition-colors"
            />
          </div>
          <span :if={@loading} class="text-sm text-base-content truncate flex-1">
            {@selected_text}
          </span>
          <.icon
            :if={@loading}
            name="hero-arrow-path"
            class="w-4 h-4 text-base-content/40 animate-spin ml-2"
          />
          <button
            :if={@show_clear && !@loading}
            type="button"
            phx-click="clear"
            phx-target={@myself}
            class="ml-2 text-base-content/40 hover:text-error transition-colors cursor-pointer"
            aria-label="Clear location"
          >
            <.icon name="hero-x-mark" class="w-4 h-4" />
          </button>
        </div>
      </div>

      <%!-- SEARCHING STATE --%>
      <div :if={!@selected} class="relative">
        <input :if={@field_name} type="hidden" name={@field_name} value={@search_text} />
        <.icon
          name="hero-map-pin"
          class="absolute left-0 top-1/2 -translate-y-1/2 w-4 h-4 text-base-content/40"
        />
        <input
          type="text"
          id={"#{@id}-input"}
          value={@search_text}
          placeholder={@placeholder}
          phx-change="search_input"
          phx-target={@myself}
          phx-debounce="300"
          phx-keydown="keydown"
          name={"#{@id}_search"}
          autocomplete="off"
          data-testid="location-input"
          role="combobox"
          aria-expanded={to_string(@show_suggestions && @suggestions != [])}
          aria-autocomplete="list"
          aria-controls={"#{@id}-listbox"}
          class="w-full h-10 pl-6 pr-6 border-0 border-b border-base-300 bg-transparent focus:border-primary focus:ring-0 focus:outline-none text-base-content text-sm"
        />
        <.icon
          :if={@loading}
          name="hero-arrow-path"
          class="absolute right-0 top-1/2 -translate-y-1/2 w-4 h-4 text-base-content/40 animate-spin"
        />

        <div
          :if={@show_suggestions && @suggestions != []}
          id={"#{@id}-listbox"}
          role="listbox"
          class="absolute z-50 w-full mt-1 border border-base-300 bg-base-200 max-h-60 overflow-y-auto shadow-[0_4px_20px_oklch(75%_0.18_195/0.15)]"
        >
          <button
            :for={{s, idx} <- Enum.with_index(@suggestions)}
            type="button"
            id={"#{@id}-option-#{idx}"}
            role="option"
            phx-click="select"
            phx-value-place-id={s.place_id}
            phx-value-display-text={s.display_text}
            phx-value-main-text={s.main_text}
            phx-target={@myself}
            class={[
              "w-full text-left px-4 py-3 border-b border-base-300 last:border-b-0 cursor-pointer",
              "border-l-2 border-l-transparent hover:bg-primary/20 hover:border-l-primary",
              idx == @suggestion_index && "bg-primary/20 border-l-primary"
            ]}
          >
            <span class="font-medium text-base-content">{s.main_text}</span>
            <span class="text-sm text-base-content/50 ml-1">{s.secondary_text}</span>
          </button>
        </div>

        <p
          :if={@show_suggestions && @suggestions == [] && !@loading}
          class="absolute z-50 w-full mt-1 px-4 py-3 border border-base-300 bg-base-200 text-sm text-base-content/50 shadow-[0_4px_20px_oklch(75%_0.18_195/0.15)]"
        >
          No locations found
        </p>
      </div>

      <p :if={@error} class="mt-1 text-sm text-error">{@error}</p>
    </div>
    """
  end

  # -- Events --

  def handle_event("search_input", params, socket) do
    # phx-change on an input sends the value under the input's name attribute
    text = params[socket.assigns.id <> "_search"] || ""

    socket =
      socket
      |> assign(search_text: text, error: nil)
      |> maybe_autocomplete(text)

    {:noreply, socket}
  end

  def handle_event(
        "select",
        %{"place-id" => place_id, "display-text" => display_text, "main-text" => main_text},
        socket
      ) do
    {:noreply, select_suggestion(socket, place_id, display_text, main_text)}
  end

  def handle_event("edit", _params, socket) do
    {:noreply,
     assign(socket,
       selected: false,
       search_text: socket.assigns.selected_text || "",
       suggestions: [],
       show_suggestions: false,
       suggestion_index: -1
     )}
  end

  def handle_event("clear", _params, socket) do
    notify_parent(socket, :cleared, nil)

    {:noreply, reset_state(socket)}
  end

  def handle_event("dismiss", _params, socket) do
    {:noreply, assign(socket, show_suggestions: false, suggestion_index: -1)}
  end

  def handle_event("keydown", %{"key" => "ArrowDown"}, socket) do
    max_idx = length(socket.assigns.suggestions) - 1
    idx = min(socket.assigns.suggestion_index + 1, max_idx)
    {:noreply, assign(socket, suggestion_index: idx)}
  end

  def handle_event("keydown", %{"key" => "ArrowUp"}, socket) do
    idx = max(socket.assigns.suggestion_index - 1, -1)
    {:noreply, assign(socket, suggestion_index: idx)}
  end

  def handle_event("keydown", %{"key" => "Escape"}, socket) do
    {:noreply, assign(socket, show_suggestions: false, suggestion_index: -1)}
  end

  def handle_event("keydown", %{"key" => "Enter"}, socket) do
    {:noreply, try_select_highlighted(socket)}
  end

  def handle_event("keydown", _params, socket) do
    {:noreply, socket}
  end

  # -- Async handlers --

  def handle_async(:autocomplete, {:ok, {:ok, suggestions}}, socket) do
    {:noreply,
     assign(socket,
       suggestions: suggestions,
       show_suggestions: true,
       loading: false,
       error: nil,
       suggestion_index: -1
     )}
  end

  def handle_async(:autocomplete, {:ok, {:error, reason}}, socket) do
    {:noreply,
     assign(socket,
       suggestions: [],
       show_suggestions: false,
       loading: false,
       error: Huddlz.Places.error_message(reason)
     )}
  end

  def handle_async(:autocomplete, {:exit, _reason}, socket) do
    {:noreply, assign(socket, loading: false)}
  end

  def handle_async(:place_details, {:ok, {:ok, %{latitude: lat, longitude: lng}}}, socket) do
    notify_parent(socket, :selected, %{
      place_id: socket.assigns.selected_place_id,
      display_text: socket.assigns.selected_text,
      main_text: socket.assigns.selected_main_text,
      latitude: lat,
      longitude: lng
    })

    {:noreply,
     assign(socket,
       selected_lat: lat,
       selected_lng: lng,
       loading: false,
       session_token: Ecto.UUID.generate()
     )}
  end

  def handle_async(:place_details, {:ok, {:error, reason}}, socket) do
    {:noreply,
     assign(socket,
       error: Huddlz.Places.error_message(reason),
       loading: false
     )}
  end

  def handle_async(:place_details, {:exit, _reason}, socket) do
    {:noreply, assign(socket, loading: false)}
  end

  # -- Private helpers --

  defp try_select_highlighted(socket) do
    idx = socket.assigns.suggestion_index

    if idx >= 0 and socket.assigns.show_suggestions do
      suggestion = Enum.at(socket.assigns.suggestions, idx)

      select_suggestion(
        socket,
        suggestion.place_id,
        suggestion.display_text,
        suggestion.main_text
      )
    else
      socket
    end
  end

  defp reset_state(socket) do
    assign(socket,
      selected: false,
      selected_text: nil,
      selected_place_id: nil,
      selected_lat: nil,
      selected_lng: nil,
      selected_main_text: nil,
      search_text: "",
      suggestions: [],
      show_suggestions: false,
      suggestion_index: -1,
      error: nil,
      session_token: Ecto.UUID.generate()
    )
  end

  defp select_suggestion(socket, place_id, display_text, main_text) do
    socket =
      assign(socket,
        selected: true,
        selected_text: display_text,
        selected_place_id: place_id,
        selected_main_text: main_text,
        suggestions: [],
        show_suggestions: false,
        suggestion_index: -1,
        search_text: ""
      )

    if socket.assigns.fetch_coordinates do
      session_token = socket.assigns.session_token

      socket
      |> assign(loading: true)
      |> start_async(:place_details, fn ->
        Huddlz.Places.place_details(place_id, session_token)
      end)
    else
      notify_parent(socket, :selected, %{
        place_id: place_id,
        display_text: display_text,
        main_text: main_text,
        latitude: nil,
        longitude: nil
      })

      assign(socket, session_token: Ecto.UUID.generate())
    end
  end

  defp maybe_autocomplete(socket, text) when byte_size(text) < 2 do
    assign(socket,
      suggestions: [],
      show_suggestions: false,
      loading: false,
      error: nil
    )
  end

  defp maybe_autocomplete(socket, text) do
    session_token = socket.assigns.session_token
    types = socket.assigns.types

    socket
    |> assign(loading: true)
    |> start_async(:autocomplete, fn ->
      Huddlz.Places.autocomplete(text, session_token, types: types)
    end)
  end

  defp notify_parent(socket, :selected, data) do
    send(self(), {:location_selected, socket.assigns.id, data})
  end

  defp notify_parent(socket, :cleared, _data) do
    send(self(), {:location_cleared, socket.assigns.id})
  end
end
