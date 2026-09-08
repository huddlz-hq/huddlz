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
  attr :placeholder, :string, default: "Search for a city..."
  attr :types, :list, default: ["locality"]
  attr :show_clear, :boolean, default: true
  attr :fetch_coordinates, :boolean, default: true

  attr :variant, :atom,
    values: [:filter_pill, :form],
    default: :form,
    doc:
      "render style — `:filter_pill` mounts inside the v3 `.filter-location` chrome; " <>
        "`:form` renders the panel-style `.location-display` block used on `/profile`"

  def mount(socket) do
    {:ok,
     assign(socket,
       # Configuration defaults (overridden by parent via update/2)
       field_name: nil,
       label: nil,
       placeholder: "Search for a city...",
       types: ["locality"],
       show_clear: true,
       fetch_coordinates: true,
       variant: :form,
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

  def render(%{variant: :filter_pill} = assigns), do: render_filter_pill(assigns)
  def render(%{variant: :form} = assigns), do: render_form(assigns)
  def render(assigns), do: render_form(assigns)

  # V3 filter-pill variant — renders inside the `.filter-location` pill chrome
  # used by `/discover`. Same events and parent notifications as the default.
  defp render_filter_pill(assigns) do
    ~H"""
    <div
      id={@id}
      class="filter-location-wrap"
      phx-click-away="dismiss"
      phx-target={@myself}
      phx-hook="LocationAutocomplete"
      data-has-highlight={to_string(@suggestion_index >= 0)}
    >
      <form class="filter-location">
        <svg
          width="14"
          height="14"
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

        <%= if @selected do %>
          <input :if={@field_name} type="hidden" name={@field_name} value={@selected_text} />
          <input
            type="text"
            class="filter-location-input"
            value={@selected_text}
            phx-click="edit"
            phx-target={@myself}
            readonly
            data-testid="location-display"
            aria-label="Edit location"
          />
          <button
            :if={@show_clear}
            type="button"
            class="filter-location-clear"
            phx-click="clear"
            phx-target={@myself}
            aria-label="Clear location"
          >
            ×
          </button>
        <% else %>
          <input :if={@field_name} type="hidden" name={@field_name} value={@search_text} />
          <input
            type="text"
            id={"#{@id}-input"}
            class="filter-location-input"
            value={@search_text}
            placeholder={@placeholder}
            phx-change="search_input"
            phx-target={@myself}
            phx-debounce="300"
            phx-keydown="keydown"
            name={"#{@id}_search"}
            autocomplete="off"
            autocorrect="off"
            autocapitalize="off"
            spellcheck="false"
            data-testid="location-input"
            role="combobox"
            aria-expanded={to_string(@show_suggestions && @suggestions != [])}
            aria-autocomplete="list"
            aria-controls={"#{@id}-listbox"}
          />
          <button
            :if={@show_clear && @search_text != ""}
            type="button"
            class="filter-location-clear"
            phx-click="clear"
            phx-target={@myself}
            aria-label="Clear location"
          >
            ×
          </button>
        <% end %>
      </form>

      <%!-- Suggestion dropdown --%>
      <div
        :if={!@selected && @show_suggestions && @suggestions != []}
        id={"#{@id}-listbox"}
        role="listbox"
        class="filter-location-listbox"
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
          class={["filter-location-option", idx == @suggestion_index && "is-active"]}
        >
          <span class="opt-main">{s.main_text}</span>
          <span class="opt-secondary">{s.secondary_text}</span>
        </button>
      </div>

      <p
        :if={!@selected && @show_suggestions && @suggestions == [] && !@loading}
        class="filter-location-listbox empty"
      >
        No locations found
      </p>

      <p :if={@error} class="filter-location-error">{@error}</p>
    </div>
    """
  end

  # V3 panel-form variant — renders the `.location-display` block on `/profile`.
  # When a location is selected, shows a static pill with explicit
  # "Change location…" and "Clear" buttons;
  # when searching, falls back to a `.form-input` + `.filter-location-listbox`
  # dropdown so the suggestions reuse the v3 panel styling.
  defp render_form(assigns) do
    ~H"""
    <div
      id={@id}
      class="filter-location-wrap"
      phx-click-away="dismiss"
      phx-target={@myself}
      phx-hook="LocationAutocomplete"
      data-has-highlight={to_string(@suggestion_index >= 0)}
    >
      <%= if @selected do %>
        <input :if={@field_name} type="hidden" name={@field_name} value={@selected_text} />
        <div class="location-display" data-testid="location-selected">
          <div class="location-current">
            <.icon name="hero-map-pin" class="size-4" />
            <span data-testid="location-display">{@selected_text}</span>
          </div>
          <div class="location-actions">
            <button
              type="button"
              class="btn-secondary"
              phx-click="edit"
              phx-target={@myself}
            >
              Change location…
            </button>
            <button
              :if={@show_clear}
              type="button"
              class="btn-secondary muted-btn"
              phx-click="clear"
              phx-target={@myself}
            >
              Clear
            </button>
          </div>
        </div>
      <% else %>
        <div class="location-control">
          <input :if={@field_name} type="hidden" name={@field_name} value={@search_text} />
          <input
            type="text"
            id={"#{@id}-input"}
            class="form-input"
            value={@search_text}
            placeholder={@placeholder}
            phx-change="search_input"
            phx-target={@myself}
            phx-debounce="300"
            phx-keydown="keydown"
            name={"#{@id}_search"}
            autocomplete="off"
            autocorrect="off"
            autocapitalize="off"
            spellcheck="false"
            data-testid="location-input"
            role="combobox"
            aria-expanded={to_string(@show_suggestions && @suggestions != [])}
            aria-autocomplete="list"
            aria-controls={"#{@id}-listbox"}
          />
          <button
            :if={@show_clear && @search_text != "" && !@loading}
            type="button"
            class="form-clear"
            phx-click="clear"
            phx-target={@myself}
            aria-label="Clear location"
          >
            ×
          </button>
        </div>

        <div
          :if={@show_suggestions && @suggestions != []}
          id={"#{@id}-listbox"}
          role="listbox"
          class="filter-location-listbox"
          style="min-width: 100%"
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
            class={["filter-location-option", idx == @suggestion_index && "is-active"]}
          >
            <span class="opt-main">{s.main_text}</span>
            <span class="opt-secondary">{s.secondary_text}</span>
          </button>
        </div>

        <p
          :if={@show_suggestions && @suggestions == [] && !@loading}
          class="filter-location-listbox empty"
          style="min-width: 100%"
        >
          No locations found
        </p>
      <% end %>

      <p :if={@error} class="form-error">{@error}</p>
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

  def handle_async(
        :place_details,
        {:ok, {:ok, %{latitude: lat, longitude: lng, time_zone: time_zone}}},
        socket
      ) do
    notify_parent(socket, :selected, %{
      place_id: socket.assigns.selected_place_id,
      display_text: socket.assigns.selected_text,
      main_text: socket.assigns.selected_main_text,
      latitude: lat,
      longitude: lng,
      time_zone: time_zone
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

  def handle_async(:place_details, {:ok, {:ok, _details}}, socket) do
    {:noreply,
     assign(socket,
       error: "That location did not include a time zone. Please choose another result.",
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
