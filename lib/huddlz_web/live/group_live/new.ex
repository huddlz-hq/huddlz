defmodule HuddlzWeb.GroupLive.New do
  @moduledoc """
  LiveView for creating a new group.
  """
  use HuddlzWeb, :live_view

  import HuddlzWeb.Live.Helpers.UploadHelpers

  alias Huddlz.Communities
  alias Huddlz.Communities.Group
  alias Huddlz.Communities.GroupImage
  alias Huddlz.Storage.GroupImages
  alias HuddlzWeb.Layouts

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    # Check if user can create groups
    if Ash.can?({Group, :create_group}, socket.assigns.current_user) do
      # Create a new changeset for the form
      form =
        AshPhoenix.Form.for_create(Group, :create_group,
          actor: socket.assigns.current_user,
          forms: [auto?: true]
        )

      {:ok,
       socket
       |> assign(:form, to_form(form))
       |> assign(:page_title, "New Group")
       |> assign(:image_error, nil)
       |> assign(:pending_image_id, nil)
       |> assign(:pending_preview_url, nil)
       |> assign(:selected_location_data, nil)
       |> assign(:modal_location_address, nil)
       |> assign(:modal_location_lat, nil)
       |> assign(:modal_location_lng, nil)
       |> assign(:upload_processing, false)
       |> allow_upload(:group_image,
         accept: ~w(.jpg .jpeg .png .webp),
         max_entries: 1,
         max_file_size: 5_000_000,
         auto_upload: true,
         progress: &handle_upload_progress/3
       )}
    else
      {:ok,
       socket
       |> put_flash(:error, "You need to be logged in to create groups")
       |> redirect(to: ~p"/groups")}
    end
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    socket =
      case socket.assigns.live_action do
        :new_location ->
          socket
          |> assign(:modal_location_address, nil)
          |> assign(:modal_location_lat, nil)
          |> assign(:modal_location_lng, nil)

        _ ->
          socket
      end

    {:noreply, socket}
  end

  defp handle_upload_progress(:group_image, entry, socket) do
    if entry.done? do
      {:noreply, process_eager_upload(socket)}
    else
      {:noreply, socket}
    end
  end

  defp process_eager_upload(socket) do
    # Clean up previous pending image if user re-uploads
    socket = cleanup_pending_image(socket)
    socket = assign(socket, :upload_processing, true)

    result =
      consume_uploaded_entries(socket, :group_image, fn %{path: path}, entry ->
        store_and_create_pending_image(path, entry, socket.assigns.current_user)
      end)

    socket = assign(socket, :upload_processing, false)
    apply_upload_result(socket, result)
  end

  defp store_and_create_pending_image(path, entry, user) do
    with {:ok, metadata} <- GroupImages.store_pending(path, entry.client_name, entry.client_type),
         {:ok, image} <- create_pending_image_record(entry, metadata, user) do
      {:ok, {:success, image.id, metadata.thumbnail_path}}
    else
      {:error, reason} -> {:ok, {:error, reason}}
    end
  end

  defp create_pending_image_record(entry, metadata, user) do
    Communities.create_pending_group_image(
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
        |> assign(:pending_preview_url, GroupImages.url(thumbnail_path))
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
        # Soft-delete previous pending image (will be cleaned up by Oban job)
        with {:ok, image} <- Ash.get(GroupImage, image_id),
             true <- is_nil(image.group_id) do
          Communities.soft_delete_group_image(image, actor: socket.assigns.current_user)
        end

        assign(socket, pending_image_id: nil, pending_preview_url: nil)
    end
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    form =
      socket.assigns.form.source
      |> AshPhoenix.Form.validate(params)

    {:noreply,
     socket
     |> assign(:form, to_form(form))
     |> assign(:image_error, nil)}
  end

  @impl true
  def handle_event("cancel_image_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :group_image, ref)}
  end

  @impl true
  def handle_event("cancel_pending_image", _params, socket) do
    {:noreply, cleanup_pending_image(socket)}
  end

  @impl true
  def handle_event("clear_location", _params, socket) do
    {:noreply,
     socket
     |> assign(:selected_location_data, nil)
     |> apply_location_to_form("")}
  end

  @impl true
  def handle_event("select_modal_location", _params, socket) do
    location_data = %{
      display_text: socket.assigns.modal_location_address,
      latitude: socket.assigns.modal_location_lat,
      longitude: socket.assigns.modal_location_lng
    }

    {:noreply,
     socket
     |> assign(:selected_location_data, location_data)
     |> apply_location_to_form(location_data.display_text)
     |> push_patch(to: ~p"/groups/new")}
  end

  @impl true
  def handle_event("save", params, socket) do
    # Extract form params, handling both wrapped and unwrapped formats
    form_params = Map.get(params, "form", params)

    # Add the current user as the owner and inject location from modal selection
    params_with_owner =
      form_params
      |> Map.put("owner_id", socket.assigns.current_user.id)
      |> inject_location_param(socket.assigns.selected_location_data)

    case socket.assigns.form.source
         |> AshPhoenix.Form.validate(params_with_owner)
         |> AshPhoenix.Form.submit(
           params: params_with_owner,
           actor: socket.assigns.current_user,
           before_submit: prepare_source_with_coordinates(socket.assigns.selected_location_data)
         ) do
      {:ok, group} ->
        # Assign pending image to the new group if one was uploaded
        assign_pending_image_to_group(socket, group)

        {:noreply,
         socket
         |> put_flash(:info, "Group created successfully")
         |> redirect(to: ~p"/groups/#{group.slug}")}

      {:error, form} ->
        {:noreply, assign(socket, :form, to_form(form))}
    end
  end

  @impl true
  def handle_info(
        {:location_selected, "modal-location-autocomplete",
         %{display_text: text, latitude: lat, longitude: lng}},
        socket
      ) do
    {:noreply,
     assign(socket,
       modal_location_address: text,
       modal_location_lat: lat,
       modal_location_lng: lng
     )}
  end

  @impl true
  def handle_info({:location_cleared, "modal-location-autocomplete"}, socket) do
    {:noreply,
     assign(socket,
       modal_location_address: nil,
       modal_location_lat: nil,
       modal_location_lng: nil
     )}
  end

  defp assign_pending_image_to_group(socket, group) do
    case socket.assigns[:pending_image_id] do
      nil ->
        :ok

      image_id ->
        with {:ok, image} <- Ash.get(GroupImage, image_id) do
          Communities.assign_group_image_to_group(image, group.id,
            actor: socket.assigns.current_user
          )
        end
    end
  end

  defp inject_location_param(params, nil), do: params

  defp inject_location_param(params, %{display_text: text}) do
    Map.put(params, "location", text)
  end

  defp prepare_source_with_coordinates(nil), do: & &1

  defp prepare_source_with_coordinates(%{latitude: lat, longitude: lng})
       when is_number(lat) and is_number(lng) do
    fn changeset ->
      changeset
      |> Ash.Changeset.force_change_attribute(:latitude, lat)
      |> Ash.Changeset.force_change_attribute(:longitude, lng)
    end
  end

  defp prepare_source_with_coordinates(_), do: & &1

  defp apply_location_to_form(socket, text) do
    current_params = socket.assigns.form.source.params || %{}
    updated_params = Map.put(current_params, "location", text)
    form = AshPhoenix.Form.validate(socket.assigns.form.source, updated_params)
    assign(socket, :form, to_form(form))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.header>
        Create a New Group
        <:subtitle>Create a group to organize huddlz and connect with others</:subtitle>
      </.header>

      <form id="group-form" phx-change="validate" phx-submit="save" class="space-y-6">
        <.input field={@form[:name]} type="text" label="Group Name" required />

        <div class="border border-base-300 p-4 bg-base-200/50">
          <p class="text-sm text-base-content/60">
            Your group will be available at:
          </p>
          <p class="font-mono text-sm mt-1 break-all">
            {url(~p"/groups/#{@form[:slug].value || "..."}")}
          </p>
        </div>

        <.input field={@form[:description]} type="textarea" label="Description" />

        <div>
          <label class="mono-label text-primary/70 mb-1.5 block">Location</label>
          <%= if @selected_location_data do %>
            <div class="flex items-center h-10 pl-6 border-0 border-b border-primary/50 bg-transparent group relative">
              <.icon
                name="hero-map-pin"
                class="absolute left-0 top-1/2 -translate-y-1/2 w-4 h-4 text-primary"
              />
              <.link
                patch={~p"/groups/new/locations/new"}
                class="flex items-center flex-1 min-w-0 cursor-pointer"
              >
                <span class="text-sm text-base-content truncate flex-1">
                  {@selected_location_data.display_text}
                </span>
                <.icon
                  name="hero-pencil"
                  class="w-3.5 h-3.5 ml-2 text-transparent group-hover:text-primary/50 transition-colors"
                />
              </.link>
              <button
                type="button"
                phx-click="clear_location"
                class="ml-2 text-base-content/40 hover:text-error transition-colors"
              >
                <.icon name="hero-x-mark" class="w-4 h-4" />
              </button>
            </div>
          <% else %>
            <.link
              patch={~p"/groups/new/locations/new"}
              class="flex items-center h-10 pl-6 border-0 border-b border-base-300 bg-transparent hover:border-primary/50 transition-colors relative"
            >
              <.icon
                name="hero-map-pin"
                class="absolute left-0 top-1/2 -translate-y-1/2 w-4 h-4 text-base-content/40"
              />
              <span class="text-sm text-base-content/50">Search for a city or region...</span>
            </.link>
          <% end %>
        </div>

        <div>
          <label class="mono-label text-primary/70 mb-2 block">
            Group Image
          </label>
          <p class="text-base-content/50 text-sm mb-3">
            Upload a banner image for your group (16:9 ratio recommended).
          </p>

          <div
            class="border border-dashed border-base-300 p-4 text-center hover:border-primary transition-colors"
            phx-drop-target={@uploads.group_image.ref}
          >
            <.live_file_input upload={@uploads.group_image} class="hidden" />
            <label for={@uploads.group_image.ref} class="cursor-pointer flex flex-col items-center">
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
              <img src={@pending_preview_url} class="w-32 aspect-video object-cover" alt="Preview" />
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
            <%= for entry <- @uploads.group_image.entries do %>
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

              <%= for err <- upload_errors(@uploads.group_image, entry) do %>
                <p class="text-error text-sm mt-1">{upload_error_to_string(err)}</p>
              <% end %>
            <% end %>
          <% end %>

          <%= for err <- upload_errors(@uploads.group_image) do %>
            <p class="text-error text-sm mt-2">{upload_error_to_string(err)}</p>
          <% end %>
        </div>

        <div>
          <label class="mono-label text-primary/70 mb-2 block">
            Privacy
          </label>
          <.input
            field={@form[:is_public]}
            type="checkbox"
            label="Public group (visible to everyone)"
          />
          <p class="text-sm text-base-content/50">
            Public groups are visible to all users. Private groups are only visible to members.
          </p>
        </div>

        <div class="flex gap-4">
          <.button type="submit" phx-disable-with="Creating...">Create Group</.button>
          <.link
            navigate={~p"/groups"}
            class="px-6 py-2 text-sm font-medium border border-base-300 hover:border-primary/30 transition-colors"
          >
            Cancel
          </.link>
        </div>
      </form>

      <.modal
        :if={@live_action == :new_location}
        id="new-location-modal"
        show
        on_cancel={JS.patch(~p"/groups/new")}
      >
        <h2 class="font-display text-xl tracking-tight text-glow mb-6">Set Location</h2>

        <form phx-submit="select_modal_location">
          <.live_component
            module={HuddlzWeb.Live.LocationAutocomplete}
            id="modal-location-autocomplete"
            label="Search for a city or region"
            placeholder="Search for a city or region..."
            types={["locality", "sublocality", "administrative_area_level_2"]}
            fetch_coordinates={true}
            show_clear={true}
          />

          <div class="mt-6 flex gap-4">
            <.button type="submit" disabled={is_nil(@modal_location_address)}>
              Use This Location
            </.button>
            <.link
              patch={~p"/groups/new"}
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
end
