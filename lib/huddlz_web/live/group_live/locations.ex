defmodule HuddlzWeb.GroupLive.Locations do
  @moduledoc """
  LiveView for managing group saved locations (address book).
  """
  use HuddlzWeb, :live_view

  alias Huddlz.Communities
  alias HuddlzWeb.Layouts

  require Ash.Query

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"slug" => slug}, _, socket) do
    user = socket.assigns.current_user

    case get_group_by_slug(slug, user) do
      {:ok, group} ->
        if authorized_to_manage?(group, user) do
          locations = load_group_locations(group.id, user)

          socket =
            socket
            |> assign(:page_title, "#{group.name} — Locations")
            |> assign(:group, group)
            |> assign(:locations, locations)
            |> assign(:modal_location_name, "")
            |> assign(:modal_location_address, nil)
            |> assign(:modal_location_lat, nil)
            |> assign(:modal_location_lng, nil)
            |> assign(:editing_location_id, nil)
            |> assign(:editing_name, "")

          {:noreply, socket}
        else
          {:noreply,
           handle_error(socket, :not_authorized,
             message: "You don't have permission to manage locations for this group",
             resource_path: ~p"/groups/#{slug}"
           )}
        end

      {:error, _} ->
        {:noreply,
         handle_error(socket, :not_found, resource_name: "Group", fallback_path: ~p"/groups")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.link
        navigate={~p"/groups/#{@group.slug}"}
        class="text-sm font-semibold leading-6 hover:underline"
      >
        <.icon name="hero-arrow-left" class="h-3 w-3" /> Back to {@group.name}
      </.link>

      <.header>
        Saved Locations
        <:subtitle>
          Manage saved addresses for <span class="font-semibold">{@group.name}</span>
        </:subtitle>
        <:actions>
          <.link
            patch={~p"/groups/#{@group.slug}/locations/new"}
            class="inline-flex items-center gap-1.5 px-4 py-2 bg-primary text-primary-content text-sm font-medium btn-neon"
          >
            <.icon name="hero-plus" class="h-4 w-4" /> Add Address
          </.link>
        </:actions>
      </.header>

      <div class="mt-8 space-y-2">
        <%= if @locations == [] do %>
          <div class="border border-dashed border-base-300 p-8 text-center">
            <.icon name="hero-map-pin" class="w-8 h-8 text-base-content/30 mx-auto mb-3" />
            <p class="text-base-content/50 text-sm">No saved locations yet.</p>
            <p class="text-base-content/40 text-xs mt-1">
              Add addresses that your group uses regularly.
            </p>
          </div>
        <% else %>
          <div :for={loc <- @locations} class="border border-base-300 p-4 flex items-center gap-4">
            <.icon name="hero-map-pin" class="w-5 h-5 text-primary/70 shrink-0" />
            <div class="flex-1 min-w-0">
              <%= if @editing_location_id == loc.id do %>
                <form phx-submit="save_rename" class="flex items-center gap-2">
                  <input type="hidden" name="location_id" value={loc.id} />
                  <input
                    type="text"
                    name="name"
                    value={@editing_name}
                    phx-change="update_editing_name"
                    phx-debounce="100"
                    class="flex-1 h-8 border-0 border-b border-base-300 bg-transparent focus:border-primary focus:ring-0 focus:outline-none text-base-content text-sm"
                    autofocus
                  />
                  <button
                    type="submit"
                    class="text-xs text-primary hover:text-primary/80 transition-colors"
                  >
                    Save
                  </button>
                  <button
                    type="button"
                    phx-click="cancel_rename"
                    class="text-xs text-base-content/40 hover:text-base-content transition-colors"
                  >
                    Cancel
                  </button>
                </form>
              <% else %>
                <p class="text-sm font-medium text-base-content truncate">
                  {loc.name || loc.address}
                </p>
                <p :if={loc.name} class="text-xs text-base-content/40 truncate">{loc.address}</p>
              <% end %>
            </div>
            <div class="flex items-center gap-2 shrink-0">
              <button
                :if={@editing_location_id != loc.id}
                type="button"
                phx-click="start_rename"
                phx-value-id={loc.id}
                class="p-1 text-base-content/30 hover:text-base-content transition-colors"
                title="Rename"
              >
                <.icon name="hero-pencil" class="w-4 h-4" />
              </button>
              <button
                type="button"
                phx-click="delete_location"
                phx-value-id={loc.id}
                data-confirm="Are you sure you want to delete this location?"
                class="p-1 text-base-content/30 hover:text-error transition-colors"
                title="Delete"
              >
                <.icon name="hero-trash" class="w-4 h-4" />
              </button>
            </div>
          </div>
        <% end %>
      </div>

      <.modal
        :if={@live_action == :new_location}
        id="new-location-modal"
        show
        on_cancel={JS.patch(~p"/groups/#{@group.slug}/locations")}
      >
        <h2 class="font-display text-xl tracking-tight text-glow mb-6">Add New Address</h2>

        <form phx-submit="save_new_location" phx-change="modal_form_changed">
          <.live_component
            module={HuddlzWeb.Live.LocationAutocomplete}
            id="modal-address-autocomplete"
            label="Search for an address"
            placeholder="Search for an address or venue..."
            types={[]}
            fetch_coordinates={true}
            show_clear={true}
          />

          <div class="mt-4">
            <label class="mono-label text-primary/70 mb-1.5 block" for="location-name-input">
              Location Name (optional)
            </label>
            <input
              type="text"
              id="location-name-input"
              name="location_name"
              value={@modal_location_name}
              phx-debounce="100"
              placeholder="e.g., Community Center"
              class="w-full h-10 border-0 border-b border-base-300 bg-transparent focus:border-primary focus:ring-0 focus:outline-none text-base-content text-sm"
            />
          </div>

          <div class="mt-6 flex gap-4">
            <.button type="submit" disabled={is_nil(@modal_location_address)}>
              Save Address
            </.button>
            <.link
              patch={~p"/groups/#{@group.slug}/locations"}
              class="px-6 py-2 text-sm font-medium border border-base-300 hover:border-primary/30 transition-colors"
            >
              Cancel
            </.link>
          </div>
        </form>
      </.modal>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("save_new_location", _params, socket) do
    user = socket.assigns.current_user
    address = socket.assigns.modal_location_address
    name = socket.assigns.modal_location_name
    name = if name == "", do: nil, else: name

    case Communities.create_group_location(
           name,
           address,
           socket.assigns.modal_location_lat,
           socket.assigns.modal_location_lng,
           socket.assigns.group.id,
           actor: user
         ) do
      {:ok, _location} ->
        locations = load_group_locations(socket.assigns.group.id, user)

        {:noreply,
         socket
         |> assign(:locations, locations)
         |> put_flash(:info, "Location saved")
         |> push_patch(to: ~p"/groups/#{socket.assigns.group.slug}/locations")}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Failed to save location")}
    end
  end

  def handle_event("modal_form_changed", %{"location_name" => name}, socket) do
    {:noreply, assign(socket, :modal_location_name, name)}
  end

  def handle_event("modal_form_changed", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("start_rename", %{"id" => id}, socket) do
    loc = Enum.find(socket.assigns.locations, &(&1.id == id))

    {:noreply,
     assign(socket,
       editing_location_id: id,
       editing_name: loc.name || ""
     )}
  end

  def handle_event("cancel_rename", _params, socket) do
    {:noreply, assign(socket, editing_location_id: nil, editing_name: "")}
  end

  def handle_event("update_editing_name", %{"name" => name}, socket) do
    {:noreply, assign(socket, :editing_name, name)}
  end

  def handle_event("save_rename", %{"location_id" => id, "name" => name}, socket) do
    loc = Enum.find(socket.assigns.locations, &(&1.id == id))
    name = if name == "", do: nil, else: name

    case Communities.update_group_location(loc, %{name: name}, actor: socket.assigns.current_user) do
      {:ok, _} ->
        locations = load_group_locations(socket.assigns.group.id, socket.assigns.current_user)

        {:noreply,
         socket
         |> assign(:locations, locations)
         |> assign(:editing_location_id, nil)
         |> assign(:editing_name, "")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to rename location")}
    end
  end

  def handle_event("delete_location", %{"id" => id}, socket) do
    loc = Enum.find(socket.assigns.locations, &(&1.id == id))

    case Communities.delete_group_location(loc, actor: socket.assigns.current_user) do
      :ok ->
        locations = load_group_locations(socket.assigns.group.id, socket.assigns.current_user)

        {:noreply,
         socket
         |> assign(:locations, locations)
         |> put_flash(:info, "Location deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete location")}
    end
  end

  @impl true
  def handle_info(
        {:location_selected, "modal-address-autocomplete",
         %{display_text: text, main_text: main_text, latitude: lat, longitude: lng}},
        socket
      ) do
    {:noreply,
     assign(socket,
       modal_location_address: text,
       modal_location_lat: lat,
       modal_location_lng: lng,
       modal_location_name: main_text || ""
     )}
  end

  def handle_info({:location_cleared, "modal-address-autocomplete"}, socket) do
    {:noreply,
     assign(socket,
       modal_location_address: nil,
       modal_location_lat: nil,
       modal_location_lng: nil,
       modal_location_name: ""
     )}
  end

  defp get_group_by_slug(slug, actor) do
    case Communities.get_by_slug(slug, actor: actor, load: [:owner]) do
      {:ok, nil} -> {:error, :not_found}
      {:ok, group} -> {:ok, group}
      {:error, _} -> {:error, :not_found}
    end
  end

  defp load_group_locations(group_id, user) do
    case Communities.list_group_locations(group_id, actor: user) do
      {:ok, locations} -> locations
      _ -> []
    end
  end

  defp authorized_to_manage?(group, user) do
    group.owner_id == user.id ||
      Huddlz.Communities.GroupMember
      |> Ash.Query.filter(group_id == ^group.id and user_id == ^user.id and role == :organizer)
      |> Ash.exists?(authorize?: false)
  end
end
