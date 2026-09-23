defmodule HuddlzWeb.Live.AddressBookLocationForm do
  @moduledoc """
  Creates an address book location from a chosen place, the organizer's own
  address text and an optional name. Pages provide the group, actor and cancel
  path, and handle `{:address_book_location_created, location}` or
  `:address_book_location_failed` to apply their own navigation and feedback.

  Choosing a place fills in the address. Once the organizer has edited it,
  choosing another place asks before replacing their words.

  Mounting starts a fresh creation attempt. Resource actions remain responsible
  for validation and authorization.
  """
  use HuddlzWeb, :live_component

  alias Huddlz.Communities

  # Place types that name a venue rather than a street or an area.
  @venue_types ~w(establishment point_of_interest premise)

  @impl true
  def mount(socket) do
    {:ok, socket |> reset() |> assign(save_label: "Save address")}
  end

  @impl true
  def update(%{location_selection: {:selected, location}}, socket) do
    suggested = suggested_address(location)

    socket =
      assign(socket, location: location, name: location[:main_text] || "")

    socket =
      if address_edited?(socket.assigns),
        do: assign(socket, pending_address: suggested),
        else: assign(socket, address: suggested, suggested_address: suggested)

    {:ok, socket}
  end

  def update(%{location_selection: {:cleared, _}}, socket) do
    {:ok, reset(socket)}
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

      <.textarea
        id="location-address-input"
        name="location_address"
        value={@address}
        rows="3"
        phx-debounce="100"
        label="Address"
        help="What people see on the huddl page and in emails and calendar invites. Change it to whatever helps them find you."
      />

      <div :if={@pending_address} class="address-replace" role="status">
        <p>You changed this address. Use the new place's address instead?</p>
        <p class="address-replace-preview">{@pending_address}</p>
        <div class="address-replace-actions">
          <.button
            variant={:secondary}
            type="button"
            phx-click="use_place_address"
            phx-target={@myself}
          >
            Use the new place's address
          </.button>
          <.button
            variant={:muted}
            type="button"
            phx-click="keep_address"
            phx-target={@myself}
          >
            Keep my address
          </.button>
        </div>
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

  def handle_event("use_place_address", _params, socket) do
    address = socket.assigns.pending_address

    {:noreply, assign(socket, address: address, suggested_address: address, pending_address: nil)}
  end

  def handle_event("keep_address", _params, socket) do
    {:noreply, assign(socket, pending_address: nil)}
  end

  def handle_event("save", params, socket) do
    socket = apply_params(socket, params)

    case create_location(socket.assigns) do
      {:ok, location} -> send(self(), {:address_book_location_created, location})
      {:error, _error} -> send(self(), :address_book_location_failed)
    end

    {:noreply, socket}
  end

  defp reset(socket) do
    assign(socket,
      location: nil,
      name: "",
      address: "",
      suggested_address: nil,
      pending_address: nil
    )
  end

  defp apply_params(socket, params) do
    assign(socket,
      name: Map.get(params, "location_name", socket.assigns.name),
      address: params |> Map.get("location_address", socket.assigns.address) |> normalize_lines()
    )
  end

  # Browsers submit textarea line breaks as CRLF; compare against the
  # suggested address the way it will be saved.
  defp normalize_lines(text), do: String.replace(text, "\r\n", "\n")

  defp address_edited?(%{address: ""}), do: false

  defp address_edited?(%{address: address, suggested_address: suggested}),
    do: address != suggested

  defp create_location(%{location: nil}), do: {:error, :unresolved_address}

  defp create_location(assigns) do
    location = assigns.location
    name = if assigns.name == "", do: nil, else: assigns.name

    Communities.create_group_location(
      name,
      assigns.address,
      location.latitude,
      location.longitude,
      location.time_zone,
      assigns.group.id,
      %{place_id: location[:place_id]},
      actor: assigns.actor
    )
  end

  # A venue's address starts with its name, which Google's formatted address
  # leaves out; a street or area is just its formatted address.
  defp suggested_address(location) do
    address = present(location[:formatted_address]) || location.display_text
    name = present(location[:main_text])

    if name && venue?(location) && !String.starts_with?(address, name),
      do: name <> "\n" <> address,
      else: address
  end

  defp venue?(location), do: Enum.any?(location[:types] || [], &(&1 in @venue_types))

  defp present(value) when is_binary(value) and value != "", do: value
  defp present(_value), do: nil
end
