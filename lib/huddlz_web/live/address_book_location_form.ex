defmodule HuddlzWeb.Live.AddressBookLocationForm do
  @moduledoc """
  Creates an address book location from a resolved address and editable name
  and unit identifier. Pages provide the group, actor and cancel path, and
  handle `{:address_book_location_created, location}` or
  `:address_book_location_failed` to apply their own navigation and feedback.

  Mounting starts a fresh creation attempt. Resource actions remain responsible
  for validation and authorization.
  """
  use HuddlzWeb, :live_component

  alias Huddlz.Communities

  @impl true
  def mount(socket) do
    {:ok, assign(socket, location: nil, name: "", unit: "", save_label: "Save address")}
  end

  @impl true
  def update(%{location_selection: {:selected, location}}, socket) do
    {:ok, assign(socket, location: location, name: location[:main_text] || "")}
  end

  def update(%{location_selection: {:cleared, _}}, socket) do
    {:ok, assign(socket, location: nil, name: "", unit: "")}
  end

  def update(assigns, socket), do: {:ok, assign(socket, assigns)}

  @impl true
  def render(assigns) do
    ~H"""
    <form
      id={@id}
      phx-target={@myself}
      phx-submit="save"
      phx-change="validate"
      class="form-grid"
    >
      <div class="form-row">
        <label class="form-label" for="modal-address-autocomplete-input">
          Search for an address
        </label>
        <.live_component
          module={HuddlzWeb.Live.LocationAutocomplete}
          id="modal-address-autocomplete"
          variant={:form}
          placeholder="Search for an address or venue..."
          types={[]}
          location_bias={%{latitude: @group.latitude, longitude: @group.longitude}}
          fetch_coordinates={true}
          show_clear={true}
          value={@location && @location.display_text}
          notify_target={@myself}
        />
      </div>

      <.input
        type="text"
        id="location-name-input"
        name="location_name"
        value={@name}
        phx-debounce="100"
        label="Location name (optional)"
        placeholder="e.g., Community Center"
      />
      <.input
        type="text"
        id="location-unit-input"
        name="location_unit"
        value={@unit}
        label="Unit (optional)"
        placeholder="e.g., 711 or 4B"
        autocomplete="address-line2"
      />

      <div class="form-foot is-flush">
        <.button variant={:primary} type="submit" disabled={is_nil(@location)}>
          {@save_label}
        </.button>
        <.button variant={:secondary} patch={@cancel_path}>Cancel</.button>
      </div>
    </form>
    """
  end

  @impl true
  def handle_event("validate", params, socket) do
    {:noreply, apply_params(socket, params)}
  end

  def handle_event("save", params, socket) do
    socket = apply_params(socket, params)

    case create_location(socket.assigns) do
      {:ok, location} -> send(self(), {:address_book_location_created, location})
      {:error, _error} -> send(self(), :address_book_location_failed)
    end

    {:noreply, socket}
  end

  defp apply_params(socket, params) do
    assign(socket,
      name: Map.get(params, "location_name", socket.assigns.name),
      unit: Map.get(params, "location_unit", socket.assigns.unit)
    )
  end

  defp create_location(%{location: nil}), do: {:error, :unresolved_address}

  defp create_location(assigns) do
    location = assigns.location
    name = if assigns.name == "", do: nil, else: assigns.name

    Communities.create_group_location(
      name,
      full_address(location),
      location.latitude,
      location.longitude,
      location.time_zone,
      assigns.group.id,
      %{unit: assigns.unit, place_id: location[:place_id]},
      actor: assigns.actor
    )
  end

  # Autocomplete's display text can be just a street and city; the resolved
  # place's formatted address is the unambiguous one.
  defp full_address(location) do
    case location[:formatted_address] do
      address when is_binary(address) and address != "" -> address
      _ -> location.display_text
    end
  end
end
