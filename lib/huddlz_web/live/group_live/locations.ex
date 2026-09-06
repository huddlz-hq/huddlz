defmodule HuddlzWeb.GroupLive.Locations do
  @moduledoc """
  LiveView for managing group saved locations (address book).
  """
  use HuddlzWeb, :live_view

  import HuddlzWeb.HuddlLive.FormHelpers, only: [load_group_locations: 2]

  alias Huddlz.Communities
  alias Huddlz.Communities.GroupLocation.DeletionImpact
  alias HuddlzWeb.Layouts
  alias HuddlzWeb.Live.Helpers.ModalLocationHelpers

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_required}
  on_mount {HuddlzWeb.LiveUserAuth, :app}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"slug" => slug}, _, socket) do
    if socket.assigns[:group] && socket.assigns.group.slug == slug do
      {:noreply, ModalLocationHelpers.clear(socket)}
    else
      load_locations_page(socket, slug)
    end
  end

  defp load_locations_page(socket, slug) do
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
            |> ModalLocationHelpers.init()
            |> assign(:editing_location_id, nil)
            |> assign(:deleting_location, nil)
            |> assign(:delete_location_reference_count, 0)
            |> assign(:delete_location_blocked?, false)
            |> assign(:rename_form, nil)

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
         handle_error(socket, :not_found,
           resource_name: "Group",
           fallback_path: ~p"/discover?#{[scope: "groups"]}"
         )}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      unread_notification_count={@unread_notification_count}
      sidebar_owned_groups={@sidebar_owned_groups}
      active="my-groups"
    >
      <p class="locations-back">
        <.link navigate={~p"/groups/#{@group.slug}"}>← Back to {@group.name}</.link>
      </p>

      <div class="page-head">
        <div>
          <h1>Saved Locations</h1>
          <p>
            Manage saved addresses for <strong>{@group.name}</strong>.
            They appear in the venue picker when you schedule a huddl.
          </p>
        </div>
        <div class="actions">
          <.button variant={:primary} patch={~p"/groups/#{@group.slug}/locations/new"}>
            Add Address
          </.button>
        </div>
      </div>

      <.panel>
        <:head>
          <h2>Addresses</h2>
        </:head>
        <:sub :if={@locations != []}>
          Click a row's actions to rename or remove it.
        </:sub>

        <%= if @locations == [] do %>
          <div class="empty-state">
            <p>No saved locations yet.</p>
            <p class="muted">
              Add addresses that your group uses regularly so you can pick them when scheduling a huddl.
            </p>
          </div>
        <% else %>
          <div class="row-list">
            <.list_row :for={loc <- @locations} class="location-row">
              <%= if @editing_location_id == loc.id do %>
                <.form
                  for={@rename_form}
                  id="location-rename-form"
                  phx-submit="save_rename"
                  class="location-rename"
                >
                  <.input
                    field={@rename_form[:name]}
                    label="Location name"
                    autocomplete="off"
                    autofocus
                  />
                  <div class="location-rename-actions">
                    <.button variant={:primary} type="submit">Save</.button>
                    <.button variant={:secondary} type="button" phx-click="cancel_rename">
                      Cancel
                    </.button>
                  </div>
                </.form>
              <% else %>
                <div class="location-info">
                  <div class="row-title">{loc.name || loc.address}</div>
                  <div :if={loc.name} class="row-desc">{loc.address}</div>
                </div>
                <div class="location-actions">
                  <.button
                    variant={:secondary}
                    type="button"
                    phx-click="start_rename"
                    phx-value-id={loc.id}
                  >
                    Rename
                  </.button>
                  <.button
                    variant={:destructive}
                    type="button"
                    id={"open-delete-location-#{loc.id}"}
                    phx-click={JS.push_focus() |> JS.push("confirm_delete_location")}
                    phx-value-id={loc.id}
                  >
                    Delete
                  </.button>
                </div>
              <% end %>
            </.list_row>
          </div>
        <% end %>
      </.panel>

      <.modal
        :if={@deleting_location}
        id="delete-location-modal"
        show
        on_cancel={JS.push("cancel_delete_location")}
      >
        <div class="delete-confirm">
          <div class="delete-confirm-icon" aria-hidden="true">
            <.icon name="hero-exclamation-triangle" class="h-6 w-6" />
          </div>

          <div class="delete-confirm-copy">
            <span class="eyebrow eyebrow-magenta">
              {if @delete_location_blocked?, do: "In use", else: "Permanent action"}
            </span>
            <h2 id="delete-location-modal-title">Delete this saved location?</h2>
            <p>
              <strong>{@deleting_location.name || @deleting_location.address}</strong>
              <span :if={@deleting_location.name}>{" — " <> @deleting_location.address}</span>
            </p>
            <p :if={!@delete_location_blocked?}>
              It will no longer appear in future venue pickers. Past huddlz keep their
              saved venue address.
            </p>
            <p :if={@delete_location_blocked?} class="delete-confirm-series-note">
              {DeletionImpact.error_message(@delete_location_reference_count)}
            </p>
          </div>
        </div>

        <div class="delete-confirm-actions">
          <.button
            variant={:muted}
            id="cancel-delete-location"
            phx-click="cancel_delete_location"
          >
            Keep location
          </.button>
          <.button
            variant={:destructive}
            class="delete-confirm-submit"
            id="confirm-delete-location"
            phx-click="delete_location"
            phx-disable-with="Deleting…"
            disabled={@delete_location_blocked?}
          >
            Delete location
          </.button>
        </div>
      </.modal>

      <.modal
        :if={@live_action == :new_location}
        id="new-location-modal"
        show
        on_cancel={JS.patch(~p"/groups/#{@group.slug}/locations")}
      >
        <h2 class="modal-title">Add New Address</h2>
        <p class="modal-sub">
          Saved venues show up in the venue picker for everyone in your group.
        </p>

        <form phx-submit="save_new_location" phx-change="modal_form_changed" class="form-grid">
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
              fetch_coordinates={true}
              show_clear={true}
            />
          </div>

          <div class="form-row">
            <label class="form-label" for="location-name-input">Location name (optional)</label>
            <input
              type="text"
              id="location-name-input"
              name="location_name"
              value={@modal_location_name}
              phx-debounce="100"
              placeholder="e.g., Community Center"
              class="form-input"
            />
          </div>

          <div class="form-foot is-flush">
            <.button variant={:primary} type="submit" disabled={is_nil(@modal_location_address)}>
              Save Address
            </.button>
            <.button variant={:secondary} patch={~p"/groups/#{@group.slug}/locations"}>
              Cancel
            </.button>
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
           socket.assigns.modal_location_time_zone,
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

  @impl true
  def handle_event("modal_form_changed", %{"location_name" => name}, socket) do
    {:noreply, assign(socket, :modal_location_name, name)}
  end

  @impl true
  def handle_event("modal_form_changed", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("start_rename", %{"id" => id}, socket) do
    loc = Enum.find(socket.assigns.locations, &(&1.id == id))

    form =
      loc
      |> AshPhoenix.Form.for_update(:update,
        actor: socket.assigns.current_user,
        as: "rename"
      )
      |> to_form()

    {:noreply,
     assign(socket,
       editing_location_id: id,
       rename_form: form
     )}
  end

  @impl true
  def handle_event("cancel_rename", _params, socket) do
    {:noreply, assign(socket, editing_location_id: nil, rename_form: nil)}
  end

  @impl true
  def handle_event("save_rename", %{"rename" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.rename_form,
           params: params,
           override_params: params
         ) do
      {:ok, _} ->
        locations = load_group_locations(socket.assigns.group.id, socket.assigns.current_user)

        {:noreply,
         socket
         |> assign(:locations, locations)
         |> assign(:editing_location_id, nil)
         |> assign(:rename_form, nil)}

      {:error, form} ->
        {:noreply, assign(socket, :rename_form, form)}
    end
  end

  @impl true
  def handle_event("confirm_delete_location", %{"id" => id}, socket) do
    with location when not is_nil(location) <-
           Enum.find(socket.assigns.locations, &(&1.id == id)),
         {:ok, references} <- DeletionImpact.active_references(location) do
      {:noreply,
       socket
       |> assign(:deleting_location, location)
       |> assign_delete_references(references)}
    else
      nil ->
        {:noreply, put_flash(socket, :error, "That location is no longer available.")}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Failed to check whether the location is in use.")}
    end
  end

  @impl true
  def handle_event("cancel_delete_location", _params, socket) do
    {:noreply, clear_delete_location(socket)}
  end

  @impl true
  def handle_event("delete_location", _params, %{assigns: %{deleting_location: nil}} = socket) do
    {:noreply, put_flash(socket, :error, "That location is no longer available.")}
  end

  def handle_event("delete_location", _params, socket) do
    location = socket.assigns.deleting_location
    user = socket.assigns.current_user

    case Communities.delete_group_location(location, actor: user) do
      :ok ->
        {:noreply,
         socket
         |> refresh_locations()
         |> clear_delete_location()
         |> put_flash(:info, "Location deleted")}

      {:ok, :already_deleted} ->
        {:noreply,
         socket
         |> refresh_locations()
         |> clear_delete_location()
         |> put_flash(:info, "Location was already deleted.")}

      {:error, _error} ->
        handle_failed_deletion(socket, location)
    end
  end

  @impl true
  def handle_info({:location_selected, "modal-address-autocomplete", payload}, socket) do
    {:noreply, ModalLocationHelpers.apply_selected(socket, payload)}
  end

  @impl true
  def handle_info({:location_cleared, "modal-address-autocomplete"}, socket) do
    {:noreply, ModalLocationHelpers.clear(socket)}
  end

  defp get_group_by_slug(slug, actor) do
    case Communities.get_by_slug(slug, actor: actor, load: [:owner]) do
      {:ok, nil} -> {:error, :not_found}
      {:ok, group} -> {:ok, group}
      {:error, _} -> {:error, :not_found}
    end
  end

  # Delegate to the GroupLocation.:create policy so this UI gate stays in
  # lockstep with the action's actual authorization rules.
  defp authorized_to_manage?(group, user) do
    Ash.can?(
      {Huddlz.Communities.GroupLocation, :create, %{group_id: group.id}},
      user
    )
  end

  defp handle_failed_deletion(socket, location) do
    socket = refresh_locations(socket)

    if Enum.any?(socket.assigns.locations, &(&1.id == location.id)) do
      case DeletionImpact.active_references(location) do
        {:ok, references} ->
          {:noreply,
           socket
           |> assign_delete_references(references)
           |> put_flash(:error, "This location cannot be deleted while it is in use.")}

        {:error, _error} ->
          {:noreply,
           socket
           |> clear_delete_location()
           |> put_flash(:error, "Failed to delete location. Please try again.")}
      end
    else
      {:noreply,
       socket
       |> clear_delete_location()
       |> put_flash(:info, "Location was already deleted.")}
    end
  end

  defp refresh_locations(socket) do
    locations = load_group_locations(socket.assigns.group.id, socket.assigns.current_user)
    assign(socket, :locations, locations)
  end

  defp clear_delete_location(socket) do
    socket
    |> assign(:deleting_location, nil)
    |> assign_delete_references([])
  end

  defp assign_delete_references(socket, references) do
    reference_count = length(references)

    assign(socket,
      delete_location_reference_count: reference_count,
      delete_location_blocked?: reference_count > 0
    )
  end
end
