defmodule HuddlzWeb.HuddlLive.New do
  @moduledoc """
  LiveView for creating a new huddl within a group.
  """
  use HuddlzWeb, :live_view

  import HuddlzWeb.HuddlLive.FormHelpers
  import HuddlzWeb.HuddlLive.FormComponent
  import HuddlzWeb.Live.Helpers.UploadHelpers

  alias Huddlz.Communities
  alias Huddlz.Communities.Huddl
  alias Huddlz.Communities.HuddlImage
  alias Huddlz.Storage.HuddlImages
  alias HuddlzWeb.Layouts

  require Ash.Query

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(%{"group_slug" => group_slug}, _session, socket) do
    user = socket.assigns.current_user

    with {:ok, group} <- get_group_by_slug(group_slug, user),
         :ok <- authorize({Huddl, :create, %{group_id: group.id}}, user) do
      group_locations = load_group_locations(group.id, user)

      socket =
        socket
        |> assign_create_form(group, user)
        |> assign(:group_locations, group_locations)
        |> assign(:selected_location, nil)
        |> assign(:modal_location_name, "")
        |> assign(:modal_location_address, nil)
        |> assign(:modal_location_lat, nil)
        |> assign(:modal_location_lng, nil)
        |> assign(:image_error, nil)
        |> assign(:pending_image_id, nil)
        |> assign(:pending_preview_url, nil)
        |> assign(:upload_processing, false)
        |> allow_upload(:huddl_image,
          accept: ~w(.jpg .jpeg .png .webp),
          max_entries: 1,
          max_file_size: 5_000_000,
          auto_upload: true,
          progress: &handle_upload_progress/3
        )

      {:ok, socket}
    else
      {:error, :not_found} ->
        {:ok,
         handle_error(socket, :not_found, resource_name: "Group", fallback_path: ~p"/groups")}

      {:error, :not_authorized} ->
        {:ok,
         handle_error(socket, :not_authorized,
           message: "You don't have permission to create huddlz for this group",
           resource_path: ~p"/groups/#{group_slug}"
         )}
    end
  end

  defp assign_create_form(socket, group, user) do
    tomorrow = Date.utc_today() |> Date.add(1)
    default_time = ~T[14:00:00]

    form =
      AshPhoenix.Form.for_create(Huddl, :create,
        domain: Huddlz.Communities,
        actor: user,
        params: %{
          "group_id" => group.id,
          "creator_id" => user.id,
          "date" => Date.to_iso8601(tomorrow),
          "start_time" => Time.to_iso8601(default_time) |> String.slice(0..4),
          "duration_minutes" => "60"
        }
      )

    socket
    |> assign(:page_title, "Create New Huddl")
    |> assign(:group, group)
    |> assign(:form, to_form(form))
    |> assign(:show_virtual_link, false)
    |> assign(:show_physical_location, true)
    |> assign(:calculated_end_time, calculate_end_time(tomorrow, default_time, 60))
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    socket =
      case socket.assigns.live_action do
        :new_location ->
          socket
          |> assign(:modal_location_name, "")
          |> assign(:modal_location_address, nil)
          |> assign(:modal_location_lat, nil)
          |> assign(:modal_location_lng, nil)

        _ ->
          socket
      end

    {:noreply, socket}
  end

  defp handle_upload_progress(:huddl_image, entry, socket) do
    if entry.done? do
      {:noreply, process_eager_upload(socket)}
    else
      {:noreply, socket}
    end
  end

  defp process_eager_upload(socket) do
    socket = cleanup_pending_image(socket)
    socket = assign(socket, :upload_processing, true)

    result =
      consume_uploaded_entries(socket, :huddl_image, fn %{path: path}, entry ->
        store_and_create_pending_image(
          path,
          entry,
          socket.assigns.current_user,
          socket.assigns.group.id
        )
      end)

    socket = assign(socket, :upload_processing, false)
    apply_upload_result(socket, result)
  end

  defp store_and_create_pending_image(path, entry, user, group_id) do
    with {:ok, metadata} <- HuddlImages.store_pending(path, entry.client_name, entry.client_type),
         {:ok, image} <- create_pending_image_record(entry, metadata, user, group_id) do
      {:ok, {:success, image.id, metadata.thumbnail_path}}
    else
      {:error, reason} -> {:ok, {:error, reason}}
    end
  end

  defp create_pending_image_record(entry, metadata, user, group_id) do
    Communities.create_pending_huddl_image(
      group_id,
      %{
        filename: entry.client_name,
        content_type: entry.client_type,
        size_bytes: metadata.size_bytes,
        storage_path: metadata.storage_path,
        thumbnail_path: metadata.thumbnail_path
      },
      actor: user
    )
  end

  defp apply_upload_result(socket, result) do
    case result do
      [{:success, image_id, thumbnail_path}] ->
        socket
        |> assign(:pending_image_id, image_id)
        |> assign(:pending_preview_url, HuddlImages.url(thumbnail_path))
        |> assign(:image_error, nil)

      [{:error, reason}] ->
        assign(socket, :image_error, format_upload_error(reason))

      [] ->
        socket
    end
  end

  defp cleanup_pending_image(socket) do
    case socket.assigns[:pending_image_id] do
      nil ->
        socket

      image_id ->
        with {:ok, image} <- Ash.get(HuddlImage, image_id),
             true <- is_nil(image.huddl_id) do
          Communities.soft_delete_huddl_image(image, actor: socket.assigns.current_user)
        end

        assign(socket, pending_image_id: nil, pending_preview_url: nil)
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
        Create New Huddl
        <:subtitle>
          Creating an event for <span class="font-semibold">{@group.name}</span>
        </:subtitle>
      </.header>

      <.form for={@form} id="huddl-form" phx-change="validate" phx-submit="save" class="space-y-6">
        <.huddl_form_fields
          form={@form}
          show_physical_location={@show_physical_location}
          show_virtual_link={@show_virtual_link}
          calculated_end_time={@calculated_end_time}
          is_public={@group.is_public}
          group_locations={@group_locations}
          selected_location={@selected_location}
          new_location_path={~p"/groups/#{@group.slug}/huddlz/new/locations/new"}
        >
          <:image_section>
            <div>
              <label class="mono-label text-primary/70 mb-2 block">
                Huddl Image
              </label>
              <p class="text-base-content/50 text-sm mb-3">
                Upload a banner image for this huddl. If none is provided, the group image will be used.
              </p>

              <div
                class="border border-dashed border-base-300 p-4 text-center hover:border-primary transition-colors"
                phx-drop-target={@uploads.huddl_image.ref}
              >
                <.live_file_input upload={@uploads.huddl_image} class="hidden" />
                <label
                  for={@uploads.huddl_image.ref}
                  class="cursor-pointer flex flex-col items-center"
                >
                  <.icon name="hero-photo" class="w-8 h-8 text-base-content/50 mb-2" />
                  <span class="text-sm text-base-content/50">
                    Click to upload or drag and drop
                  </span>
                  <span class="text-xs text-base-content/50 mt-1">
                    JPG, PNG, or WebP (max 5MB)
                  </span>
                </label>
              </div>

              <%= if @image_error do %>
                <p class="text-error text-sm mt-2">{@image_error}</p>
              <% end %>

              <%= if @pending_preview_url do %>
                <div class="mt-3 flex items-center gap-3 p-3 bg-base-200">
                  <img
                    src={@pending_preview_url}
                    class="w-32 aspect-video object-cover"
                    alt="Preview"
                  />
                  <div class="flex-1 min-w-0">
                    <p class="text-sm font-medium text-success flex items-center gap-1">
                      <.icon name="hero-check-circle" class="w-4 h-4" /> Image uploaded
                    </p>
                  </div>
                  <button
                    type="button"
                    phx-click="cancel_pending_image"
                    class="p-1 hover:bg-base-300 text-base-content/50 hover:text-base-content transition-colors"
                  >
                    <.icon name="hero-x-mark" class="w-4 h-4" />
                  </button>
                </div>
              <% else %>
                <%= for entry <- @uploads.huddl_image.entries do %>
                  <div class="mt-3 flex items-center gap-3 p-3 bg-base-200">
                    <.live_img_preview entry={entry} class="w-32 aspect-video object-cover" />
                    <div class="flex-1 min-w-0">
                      <p class="text-sm font-medium truncate">{entry.client_name}</p>
                      <div class="w-full bg-base-300 rounded-full h-1.5 mt-1">
                        <div
                          class="bg-primary h-1.5 rounded-full transition-all"
                          style={"width: #{entry.progress}%"}
                        >
                        </div>
                      </div>
                    </div>
                    <button
                      type="button"
                      phx-click="cancel_image_upload"
                      phx-value-ref={entry.ref}
                      class="p-1 hover:bg-base-300 text-base-content/50 hover:text-base-content transition-colors"
                    >
                      <.icon name="hero-x-mark" class="w-4 h-4" />
                    </button>
                  </div>

                  <%= for err <- upload_errors(@uploads.huddl_image, entry) do %>
                    <p class="text-error text-sm mt-1">{upload_error_to_string(err)}</p>
                  <% end %>
                <% end %>
              <% end %>

              <%= for err <- upload_errors(@uploads.huddl_image) do %>
                <p class="text-error text-sm mt-2">{upload_error_to_string(err)}</p>
              <% end %>
            </div>
          </:image_section>

          <:recurring_section>
            <.input field={@form[:is_recurring]} type="checkbox" label="Make this a recurring event" />

            <%= if @form[:is_recurring].value do %>
              <div class="grid gap-4 sm:grid-cols-2">
                <.input
                  field={@form[:frequency]}
                  type="select"
                  label="Frequency"
                  options={[
                    {"Weekly", "weekly"},
                    {"Monthly", "monthly"}
                  ]}
                  required
                />
                <.input field={@form[:repeat_until]} type="date" label="Repeat Until" required />
              </div>
            <% end %>
          </:recurring_section>

          <:actions>
            <div class="flex gap-4">
              <.button type="submit" phx-disable-with="Creating...">
                Create Huddl
              </.button>
              <.link
                navigate={~p"/groups/#{@group.slug}"}
                class="px-6 py-2 text-sm font-medium border border-base-300 hover:border-primary/30 transition-colors"
              >
                Cancel
              </.link>
            </div>
          </:actions>
        </.huddl_form_fields>
      </.form>

      <.modal
        :if={@live_action == :new_location}
        id="new-location-modal"
        show
        on_cancel={JS.patch(~p"/groups/#{@group.slug}/huddlz/new")}
      >
        <h2 class="font-display text-xl tracking-tight text-glow mb-6">Add New Address</h2>

        <form phx-submit="save_location" phx-change="modal_form_changed">
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
              patch={~p"/groups/#{@group.slug}/huddlz/new"}
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
  def handle_event("cancel_image_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :huddl_image, ref)}
  end

  @impl true
  def handle_event("cancel_pending_image", _params, socket) do
    {:noreply, cleanup_pending_image(socket)}
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    params = inject_saved_location_params(params, socket.assigns[:selected_location])

    socket =
      socket
      |> update_event_type_visibility(params)
      |> update_calculated_end_time(params)

    form = AshPhoenix.Form.validate(socket.assigns.form, params)
    {:noreply, assign(socket, :form, to_form(form))}
  end

  def handle_event("save", %{"form" => params}, socket) do
    params =
      if socket.assigns.group.is_public do
        params
      else
        Map.put(params, "is_private", "true")
      end

    params =
      params
      |> Map.put("group_id", socket.assigns.group.id)
      |> Map.put("creator_id", socket.assigns.current_user.id)
      |> inject_saved_location_params(socket.assigns[:selected_location])

    case AshPhoenix.Form.submit(socket.assigns.form,
           params: params,
           actor: socket.assigns.current_user,
           before_submit: prepare_source_with_coordinates(socket.assigns[:selected_location])
         ) do
      {:ok, huddl} ->
        assign_pending_image_to_huddl(socket, huddl)

        {:noreply,
         socket
         |> put_flash(:info, "Huddl created successfully!")
         |> redirect(to: ~p"/groups/#{socket.assigns.group.slug}")}

      {:error, form} ->
        {:noreply, assign(socket, :form, to_form(form))}
    end
  end

  def handle_event("save_location", _params, socket) do
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
      {:ok, location} ->
        group_locations = load_group_locations(socket.assigns.group.id, user)

        {:noreply,
         socket
         |> assign(:group_locations, group_locations)
         |> apply_saved_location_to_form(location)
         |> push_patch(to: ~p"/groups/#{socket.assigns.group.slug}/huddlz/new")}

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

  @impl true
  def handle_info({:saved_location_selected, "saved-location-picker", location}, socket) do
    {:noreply, apply_saved_location_to_form(socket, location)}
  end

  def handle_info({:saved_location_cleared, "saved-location-picker"}, socket) do
    {:noreply, clear_saved_location(socket)}
  end

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

  defp assign_pending_image_to_huddl(socket, huddl) do
    case socket.assigns[:pending_image_id] do
      nil ->
        :ok

      image_id ->
        with {:ok, image} <- Ash.get(HuddlImage, image_id) do
          Communities.assign_huddl_image_to_huddl(image, huddl.id,
            actor: socket.assigns.current_user
          )
        end
    end
  end

  defp get_group_by_slug(slug, actor) do
    case Huddlz.Communities.get_by_slug(slug, actor: actor, load: [:owner]) do
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
end
