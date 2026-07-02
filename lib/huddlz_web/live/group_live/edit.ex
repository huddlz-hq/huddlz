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

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_required}
  on_mount {HuddlzWeb.LiveUserAuth, :app}

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    user = socket.assigns.current_user

    with {:ok, group} <- get_group_by_slug(slug, user),
         :ok <- authorize({group, :update_details}, user) do
      {:ok, assign_edit_form(socket, group)}
    else
      {:error, :not_found} ->
        {:ok,
         handle_error(socket, :not_found,
           resource_name: "Group",
           fallback_path: ~p"/discover?#{[scope: "groups"]}"
         )}

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
    |> assign(:upload_processing, false)
    |> allow_image_upload(:group_image, &handle_upload_progress/3)
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
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      sidebar_owned_groups={@sidebar_owned_groups}
      active="my-groups"
    >
      <div class="page-head">
        <div>
          <h1>Edit Group</h1>
          <p>Update group details, photo, and visibility. Changes save when you hit save.</p>
        </div>
      </div>

      <.form for={@form} id="edit-group-form" phx-change="validate" phx-submit="update_group">
        <div class="panel">
          <div class="panel-head">
            <h2>Cover image</h2>
          </div>

          <label for={@uploads.group_image.ref} class="sr-only">Cover image</label>
          <.live_file_input upload={@uploads.group_image} class="hidden" />

          <%= cond do %>
            <% @pending_preview_url -> %>
              <div class="image-preview" phx-drop-target={@uploads.group_image.ref}>
                <div
                  class="card-cover"
                  style={"background-image: url('#{@pending_preview_url}')"}
                >
                </div>
                <div class="image-preview-foot">
                  <span class="muted">New image uploaded. Save to apply.</span>
                  <div class="image-preview-actions">
                    <.button variant={:primary} type="submit" phx-disable-with="Saving...">
                      Save
                    </.button>
                    <label for={@uploads.group_image.ref} class="btn-secondary upload-replace">
                      Replace
                    </label>
                    <.button variant={:muted} type="button" phx-click="cancel_pending_image">
                      Remove
                    </.button>
                  </div>
                </div>
              </div>
            <% @group.current_image_url && @uploads.group_image.entries == [] -> %>
              <div class="image-preview" phx-drop-target={@uploads.group_image.ref}>
                <div
                  class="card-cover"
                  style={"background-image: url('#{GroupImages.url(@group.current_image_url)}')"}
                >
                </div>
                <div class="image-preview-foot">
                  <span class="muted">Current image. Upload a new one to replace it.</span>
                  <div class="image-preview-actions">
                    <label for={@uploads.group_image.ref} class="btn-secondary upload-replace">
                      Replace
                    </label>
                    <.button
                      variant={:muted}
                      type="button"
                      phx-click="remove_image"
                      data-confirm="Are you sure you want to remove this image?"
                    >
                      Remove
                    </.button>
                  </div>
                </div>
              </div>
            <% true -> %>
              <div class="upload-zone" phx-drop-target={@uploads.group_image.ref}>
                <div class="upload-icon">
                  <svg
                    width="22"
                    height="22"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="1.6"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    aria-hidden="true"
                  >
                    <rect x="3" y="3" width="18" height="18" rx="2" />
                    <circle cx="9" cy="9" r="2" />
                    <path d="m21 15-5-5L5 21" />
                  </svg>
                </div>
                <label for={@uploads.group_image.ref} class="upload-prompt">
                  Drop a 16:9 image, or <span class="upload-link">browse</span>
                </label>
                <div class="upload-meta muted">JPG, PNG, WebP · 5 MB max</div>
              </div>

              <%= for entry <- @uploads.group_image.entries do %>
                <div class="image-preview image-preview-progress">
                  <.live_img_preview entry={entry} class="card-cover-img" />
                  <div class="image-preview-foot">
                    <span class="muted">{entry.client_name} · {entry.progress}%</span>
                    <.button
                      variant={:muted}
                      type="button"
                      phx-click="cancel_image_upload"
                      phx-value-ref={entry.ref}
                    >
                      Cancel
                    </.button>
                  </div>
                </div>

                <%= for err <- upload_errors(@uploads.group_image, entry) do %>
                  <p class="form-error">{upload_error_to_string(err)}</p>
                <% end %>
              <% end %>
          <% end %>

          <p :if={@image_error} class="form-error">{@image_error}</p>

          <%= for err <- upload_errors(@uploads.group_image) do %>
            <p class="form-error">{upload_error_to_string(err)}</p>
          <% end %>
        </div>

        <div class="panel">
          <div class="panel-head">
            <h2>The basics</h2>
          </div>
          <div class="form-grid">
            <.input
              field={@form[:name]}
              label="Group Name"
              autocomplete="off"
            />

            <div class="form-row">
              <label class="form-label" for={@form[:slug].id}>URL Slug</label>
              <div class="slug-control">
                <span class="slug-prefix">huddlz.com/groups/</span>
                <input
                  id={@form[:slug].id}
                  type="text"
                  name={@form[:slug].name}
                  value={@form[:slug].value}
                  class="form-input"
                  pattern="[a-z0-9-]+"
                  title="Only lowercase letters, numbers, and hyphens allowed"
                />
              </div>
              <p :if={!@slug_changed} class="form-help">
                Your group is available at: {url(~p"/groups/#{@form[:slug].value || "..."}")}
              </p>
              <div :if={@slug_changed} class="slug-warn">
                <h3>Warning: URL Change</h3>
                <p>Changing the slug will break existing links to this group.</p>
                <p>Old URL: <span class="mono">{url(~p"/groups/#{@original_slug}")}</span></p>
                <p>New URL: <span class="mono">{url(~p"/groups/#{@form[:slug].value}")}</span></p>
              </div>
            </div>

            <.textarea
              field={@form[:description]}
              label="Description"
              rows="4"
            />

            <div class="form-row">
              <label class="form-label" for="group-location-input">Location</label>
              <.live_component
                module={HuddlzWeb.Live.LocationAutocomplete}
                id="group-location"
                variant={:form}
                field_name="form[location]"
                value={@form[:location].value}
                latitude={@selected_location_data && @selected_location_data.latitude}
                longitude={@selected_location_data && @selected_location_data.longitude}
                placeholder="Search for a city or region..."
                types={["locality", "sublocality", "administrative_area_level_2"]}
                fetch_coordinates={true}
                show_clear={true}
              />
              <p class="form-help">
                Optional. Helps people find your group when they search nearby.
              </p>
            </div>
          </div>
        </div>

        <div class="panel">
          <div class="panel-head">
            <div>
              <h2>Visibility</h2>
              <div class="panel-sub">
                Public groups are findable in Discover. Private groups are only visible to members.
              </div>
            </div>
          </div>
          <div class="settings-list row-list pref-list">
            <div class="row">
              <div>
                <label class="row-title" for="group-is-public">Public group</label>
                <div class="row-desc">
                  Anyone can find and join this group. Huddlz are visible without signing in.
                </div>
              </div>
              <label class="toggle">
                <input type="hidden" name={@form[:is_public].name} value="false" />
                <input
                  id="group-is-public"
                  type="checkbox"
                  name={@form[:is_public].name}
                  value="true"
                  checked={Phoenix.HTML.Form.normalize_value("checkbox", @form[:is_public].value)}
                />
                <span class="track"></span>
                <span class="toggle-text">
                  {if Phoenix.HTML.Form.normalize_value("checkbox", @form[:is_public].value),
                    do: "On",
                    else: "Off"}
                </span>
              </label>
            </div>
          </div>
        </div>

        <div class="form-foot">
          <.button variant={:primary} type="submit" phx-disable-with="Saving...">
            Save Changes
          </.button>
          <.button variant={:secondary} navigate={~p"/groups/#{@original_slug}"}>
            Cancel
          </.button>
        </div>
      </.form>
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

    case soft_delete_all_group_images(group, user) do
      :ok ->
        {:ok, updated_group} = Ash.load(group, [:current_image_url], actor: user)

        {:noreply,
         socket
         |> put_flash(:info, "Image removed")
         |> assign(:group, updated_group)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to remove image")}
    end
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
  def handle_info({:location_selected, "group-location", payload}, socket) do
    location_data = %{
      display_text: payload.display_text,
      latitude: payload.latitude,
      longitude: payload.longitude
    }

    {:noreply,
     socket
     |> assign(:selected_location_data, location_data)
     |> apply_group_location_to_form(location_data.display_text)}
  end

  @impl true
  def handle_info({:location_cleared, "group-location"}, socket) do
    {:noreply,
     socket
     |> assign(:selected_location_data, nil)
     |> apply_group_location_to_form("")}
  end

  defp assign_pending_image_to_group(socket, group) do
    case socket.assigns[:pending_image_id] do
      nil ->
        :ok

      image_id ->
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
