defmodule HuddlzWeb.GroupLive.Edit do
  @moduledoc """
  LiveView for editing an existing group's details.
  """
  use HuddlzWeb, :live_view

  import HuddlzWeb.Live.Helpers.UploadHelpers

  import HuddlzWeb.HuddlLive.FormHelpers,
    only: [
      inject_group_location_param: 2,
      prepare_source_with_coordinates: 1,
      apply_group_location_to_form: 2
    ]

  alias Huddlz.Communities
  alias Huddlz.Communities.GroupImage
  alias Huddlz.Storage.GroupImages
  alias HuddlzWeb.Layouts
  alias HuddlzWeb.Live.Helpers.ImageUploadPipeline
  alias HuddlzWeb.Live.Helpers.ModalLocationHelpers

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    user = socket.assigns.current_user

    with {:ok, group} <- get_group_by_slug(slug, user),
         :ok <- authorize({group, :update_details}, user) do
      {:ok, assign_edit_form(socket, group)}
    else
      {:error, :not_found} ->
        {:ok,
         handle_error(socket, :not_found, resource_name: "Group", fallback_path: ~p"/groups")}

      {:error, :not_authorized} ->
        {:ok,
         handle_error(socket, :not_authorized,
           resource_name: "group",
           action: "edit",
           resource_path: ~p"/groups/#{slug}"
         )}
    end
  end

  defp assign_edit_form(socket, group) do
    form =
      AshPhoenix.Form.for_update(group, :update_details,
        actor: socket.assigns.current_user,
        forms: [auto?: true]
      )
      |> to_form()

    socket
    |> assign(:page_title, "Edit Group")
    |> assign(:group, group)
    |> assign(:form, form)
    |> assign(:original_slug, group.slug)
    |> assign(:slug_changed, false)
    |> assign(:image_error, nil)
    |> assign(:pending_image_id, nil)
    |> assign(:pending_preview_url, nil)
    |> assign(:selected_location_data, build_initial_location_data(group))
    |> ModalLocationHelpers.init()
    |> assign(:upload_processing, false)
    |> allow_upload(:group_image,
      accept: ~w(.jpg .jpeg .png .webp),
      max_entries: 1,
      max_file_size: 5_000_000,
      auto_upload: true,
      progress: &handle_upload_progress/3
    )
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    socket =
      case socket.assigns.live_action do
        :new_location -> ModalLocationHelpers.clear(socket)
        _ -> socket
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

  defp process_eager_upload(socket),
    do: ImageUploadPipeline.process_eager_upload(socket, upload_config())

  defp cleanup_pending_image(socket),
    do: ImageUploadPipeline.cleanup_pending_image(socket, upload_config())

  defp upload_config do
    %{
      upload_name: :group_image,
      storage: GroupImages,
      create_pending: &create_pending_group_image/3,
      cleanup: &soft_delete_pending_group_image/2
    }
  end

  defp create_pending_group_image(socket, entry, metadata) do
    Communities.create_pending_group_image(
      %{
        filename: entry.client_name,
        content_type: entry.client_type,
        size_bytes: metadata.size_bytes,
        storage_path: metadata.storage_path,
        thumbnail_path: metadata.thumbnail_path
      },
      actor: socket.assigns.current_user
    )
  end

  defp soft_delete_pending_group_image(socket, image_id) do
    with {:ok, image} <- Ash.get(GroupImage, image_id),
         true <- is_nil(image.group_id) do
      Communities.soft_delete_group_image(image, actor: socket.assigns.current_user)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.link
        navigate={~p"/groups/#{@original_slug}"}
        class="text-sm font-semibold leading-6 hover:underline"
      >
        <.icon name="hero-arrow-left" class="h-3 w-3" /> Back to {@group.name}
      </.link>

      <.header>
        Edit Group
        <:subtitle>Update your group details</:subtitle>
      </.header>

      <form
        id="edit-group-form"
        phx-submit="update_group"
        phx-change="validate"
        class="space-y-6 mt-6"
      >
        <.input field={@form[:name]} type="text" label="Group Name" required />

        <div>
          <.input
            field={@form[:slug]}
            type="text"
            label="URL Slug"
            pattern="[a-z0-9-]+"
            title="Only lowercase letters, numbers, and hyphens allowed"
            required
          />
          <p class="text-sm text-base-content/60 mt-1">
            Your group is available at:
          </p>
          <p class="font-mono text-sm mt-1 break-all">
            {url(~p"/groups/#{@form[:slug].value || "..."}")}
          </p>

          <%= if @slug_changed do %>
            <div class="border border-warning/30 p-4 bg-warning/5 mt-2">
              <div class="flex">
                <div class="flex-shrink-0">
                  <.icon name="hero-exclamation-triangle" class="h-5 w-5 text-warning" />
                </div>
                <div class="ml-3">
                  <h3 class="text-sm font-medium text-warning">
                    Warning: URL Change
                  </h3>
                  <div class="mt-2 text-sm text-base-content/50">
                    <p>Changing the slug will break existing links to this group.</p>
                    <p class="mt-1 break-all">
                      Old URL: <span class="font-mono">{url(~p"/groups/#{@original_slug}")}</span>
                    </p>
                    <p class="break-all">
                      New URL: <span class="font-mono">{url(~p"/groups/#{@form[:slug].value}")}</span>
                    </p>
                  </div>
                </div>
              </div>
            </div>
          <% end %>
        </div>

        <.input field={@form[:description]} type="textarea" label="Description" rows="4" />

        <div>
          <label class="mono-label text-primary/70 mb-1.5 block">Location</label>
          <%= if @selected_location_data do %>
            <div class="flex items-center h-10 pl-6 border-0 border-b border-primary/50 bg-transparent group relative">
              <.icon
                name="hero-map-pin"
                class="absolute left-0 top-1/2 -translate-y-1/2 w-4 h-4 text-primary"
              />
              <.link
                patch={~p"/groups/#{@original_slug}/edit/locations/new"}
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
              patch={~p"/groups/#{@original_slug}/edit/locations/new"}
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

          <%= if @pending_preview_url do %>
            <div class="mb-4">
              <div class="relative inline-block">
                <img
                  src={@pending_preview_url}
                  alt="New image preview"
                  class="max-w-md aspect-video object-cover"
                />
                <button
                  type="button"
                  phx-click="cancel_pending_image"
                  class="absolute top-2 right-2 p-1.5 bg-error/10 text-error hover:bg-error/20 transition-colors"
                >
                  <.icon name="hero-x-mark" class="w-4 h-4" />
                </button>
              </div>
              <p class="text-sm text-success mt-2 flex items-center gap-1">
                <.icon name="hero-check-circle" class="w-4 h-4" /> New image uploaded. Save to apply.
              </p>
            </div>
          <% else %>
            <%= if @group.current_image_url && @uploads.group_image.entries == [] do %>
              <div class="mb-4">
                <div class="relative inline-block">
                  <img
                    src={GroupImages.url(@group.current_image_url)}
                    alt={@group.name}
                    class="max-w-md aspect-video object-cover"
                  />
                  <button
                    type="button"
                    phx-click="remove_image"
                    class="absolute top-2 right-2 p-1.5 bg-error/10 text-error hover:bg-error/20 transition-colors"
                    data-confirm="Are you sure you want to remove this image?"
                  >
                    <.icon name="hero-trash" class="w-4 h-4" />
                  </button>
                </div>
                <p class="text-sm text-base-content/50 mt-2">
                  Current image. Upload a new one to replace it.
                </p>
              </div>
            <% end %>
          <% end %>

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
          <.button type="submit" phx-disable-with="Saving...">
            Save Changes
          </.button>
          <.link
            navigate={~p"/groups/#{@original_slug}"}
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
        on_cancel={JS.patch(~p"/groups/#{@original_slug}/edit")}
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
              patch={~p"/groups/#{@original_slug}/edit"}
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
  def handle_event("validate", %{"form" => params}, socket) do
    form =
      socket.assigns.form.source
      |> AshPhoenix.Form.validate(params)
      |> to_form()

    slug_changed = params["slug"] != socket.assigns.original_slug

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:slug_changed, slug_changed)
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
  def handle_event("remove_image", _params, socket) do
    group = socket.assigns.group
    user = socket.assigns.current_user

    # Soft-delete all images for the group
    case soft_delete_all_group_images(group, user) do
      :ok ->
        # Reload group to clear the image
        {:ok, updated_group} =
          Ash.load(group, [:current_image_url], actor: user)

        {:noreply,
         socket
         |> put_flash(:info, "Image removed")
         |> assign(:group, updated_group)}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to remove image")}
    end
  end

  @impl true
  def handle_event("clear_location", _params, socket) do
    {:noreply,
     socket
     |> assign(:selected_location_data, nil)
     |> apply_group_location_to_form("")}
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
     |> apply_group_location_to_form(location_data.display_text)
     |> push_patch(to: ~p"/groups/#{socket.assigns.original_slug}/edit")}
  end

  @impl true
  def handle_event("update_group", %{"form" => params}, socket) do
    params = inject_group_location_param(params, socket.assigns.selected_location_data)

    case AshPhoenix.Form.submit(socket.assigns.form.source,
           params: params,
           actor: socket.assigns.current_user,
           before_submit: prepare_source_with_coordinates(socket.assigns.selected_location_data)
         ) do
      {:ok, updated_group} ->
        # Assign pending image to the group if one was uploaded
        assign_pending_image_to_group(socket, updated_group)

        {:noreply,
         socket
         |> put_flash(:info, "Group updated successfully")
         |> redirect(to: ~p"/groups/#{updated_group.slug}")}

      {:error, form} ->
        {:noreply, assign(socket, :form, to_form(form))}
    end
  end

  @impl true
  def handle_info({:location_selected, "modal-location-autocomplete", payload}, socket) do
    {:noreply, ModalLocationHelpers.apply_selected(socket, payload)}
  end

  @impl true
  def handle_info({:location_cleared, "modal-location-autocomplete"}, socket) do
    {:noreply, ModalLocationHelpers.clear(socket)}
  end

  defp assign_pending_image_to_group(socket, group) do
    case socket.assigns[:pending_image_id] do
      nil ->
        :ok

      image_id ->
        # Soft-delete existing images before assigning new one
        soft_delete_all_group_images(group, socket.assigns.current_user)

        with {:ok, image} <- Ash.get(GroupImage, image_id) do
          Communities.assign_group_image_to_group(image, group.id,
            actor: socket.assigns.current_user
          )
        end
    end
  end

  defp soft_delete_all_group_images(group, user) do
    case Huddlz.Communities.list_group_images(group.id, actor: user) do
      {:ok, images} ->
        Enum.each(images, fn image ->
          Huddlz.Communities.soft_delete_group_image(image, actor: user)
        end)

        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_initial_location_data(group) do
    if group.location && group.latitude && group.longitude do
      %{
        display_text: to_string(group.location),
        latitude: group.latitude,
        longitude: group.longitude
      }
    else
      nil
    end
  end

  defp get_group_by_slug(slug, actor) do
    case Huddlz.Communities.get_by_slug(slug,
           actor: actor,
           load: [:owner, :current_image_url]
         ) do
      {:ok, nil} -> {:error, :not_found}
      {:ok, group} -> {:ok, group}
      {:error, _} -> {:error, :not_found}
    end
  end
end
