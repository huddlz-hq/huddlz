defmodule HuddlzWeb.GroupLive.Edit do
  @moduledoc """
  LiveView for editing an existing group's details.
  """
  use HuddlzWeb, :live_view

  import HuddlzWeb.Live.Helpers.UploadHelpers

  import HuddlzWeb.HuddlLive.FormHelpers,
    only: [
      inject_group_location_param: 2,
      put_provided_coordinates: 2,
      apply_group_location_to_form: 2,
      apply_time_zone_to_form: 3
    ]

  alias Huddlz.Communities
  alias Huddlz.Communities.GroupImage
  alias Huddlz.Storage.GroupImages
  alias HuddlzWeb.Layouts
  alias HuddlzWeb.Live.Helpers.ImageUploadPipeline
  alias Phoenix.LiveView.JS

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
    |> assign(:remove_image_dialog_open, false)
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
    selected_public? = public_group?(assigns.form)

    assigns =
      assigns
      |> assign(:selected_public?, selected_public?)
      |> assign(
        :visibility_changed?,
        visibility_changed?(assigns.group.is_public, selected_public?)
      )

    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      unread_notification_count={@unread_notification_count}
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
                      id="open-remove-group-image-dialog"
                      type="button"
                      phx-click={JS.push_focus() |> JS.push("open_remove_image_dialog")}
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

            <.input
              field={@form[:slug]}
              label="URL Slug"
              control_class="slug-control"
              help={
                !@slug_changed &&
                  "Your group is available at: #{url(~p"/groups/#{@form[:slug].value || "..."}")}"
              }
            >
              <:prefix>
                <span class="slug-prefix">huddlz.com/groups/</span>
              </:prefix>
              <:details :if={@slug_changed}>
                <div class="slug-warn">
                  <h3>Warning: URL Change</h3>
                  <p>Changing the slug will break existing links to this group.</p>
                  <p>Old URL: <span class="mono">{url(~p"/groups/#{@original_slug}")}</span></p>
                  <p>New URL: <span class="mono">{url(~p"/groups/#{@form[:slug].value}")}</span></p>
                </div>
              </:details>
            </.input>

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
              <.field_errors field={@form[:location]} />
              <p class="form-help">
                Optional. Helps people find your group when they search nearby.
              </p>
            </div>
            <.live_component
              module={HuddlzWeb.Live.TimeZoneSelect}
              id="group-time-zone"
              field={@form[:time_zone]}
              label="Time zone"
              help="Applies to new huddlz you create in this group unless you set a different time zone on the huddl itself."
            />
          </div>
        </div>

        <div class="panel">
          <div class="panel-head visibility-panel-head">
            <div>
              <h2>Visibility</h2>
              <div class="panel-sub">
                Choose who can find this group and its huddlz.
              </div>
            </div>
            <div
              id="group-visibility-current"
              class="visibility-current"
            >
              <span>Current visibility</span>
              <strong>{visibility_label(@group.is_public)}</strong>
            </div>
          </div>
          <div class="settings-list row-list pref-list">
            <div
              id="group-visibility-selection"
              class="row visibility-selection"
            >
              <div>
                <div id="group-visibility-label" class="row-title">
                  {visibility_label(@selected_public?)} group
                </div>
                <div id="group-visibility-description" class="row-desc">
                  {visibility_description(@selected_public?)}
                </div>
              </div>
              <label id="group-public-toggle-label" for="group-is-public" class="sr-only">
                Public group
              </label>
              <label class="toggle visibility-toggle">
                <input type="hidden" name={@form[:is_public].name} value="false" />
                <input
                  id="group-is-public"
                  type="checkbox"
                  name={@form[:is_public].name}
                  value="true"
                  checked={@selected_public?}
                  role="switch"
                  aria-checked={to_string(@selected_public?)}
                  aria-labelledby="group-public-toggle-label"
                  aria-describedby="group-visibility-description group-visibility-consequence"
                />
                <span class="track"></span>
                <span class="toggle-text">
                  {visibility_label(@selected_public?)}
                </span>
              </label>
            </div>
          </div>
          <div
            id="group-visibility-consequence"
            class={[
              "visibility-consequence",
              @visibility_changed? && "visibility-consequence-pending"
            ]}
            role="status"
            aria-live="polite"
          >
            <.icon
              name={
                if @visibility_changed?,
                  do: "hero-arrow-right",
                  else: "hero-check"
              }
              class="visibility-consequence-icon size-4"
            />
            <span>{visibility_consequence(@group.is_public, @selected_public?)}</span>
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

      <.modal
        :if={@remove_image_dialog_open}
        id="remove-group-image-dialog"
        show
        on_cancel={JS.push("cancel_remove_image")}
      >
        <div class="delete-confirm">
          <div class="delete-confirm-icon" aria-hidden="true">
            <.icon name="hero-photo" class="h-6 w-6" />
          </div>

          <div class="delete-confirm-copy">
            <span class="eyebrow eyebrow-magenta">Group cover</span>
            <h2 id="remove-group-image-dialog-title">Remove this group cover image?</h2>
            <p>
              The current cover for <strong>{@group.name}</strong> will be removed. Group and
              huddl cards will use the <strong>branded group fallback</strong> until a new cover
              is uploaded.
            </p>
          </div>
        </div>

        <div class="delete-confirm-actions">
          <.button
            variant={:muted}
            id="cancel-remove-group-image"
            phx-click="cancel_remove_image"
          >
            Keep image
          </.button>
          <.button
            variant={:destructive}
            class="delete-confirm-submit"
            id="confirm-remove-group-image"
            phx-click="remove_image"
            phx-disable-with="Removing…"
          >
            Remove image
          </.button>
        </div>
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
  def handle_event("open_remove_image_dialog", _params, socket) do
    {:noreply,
     assign(
       socket,
       :remove_image_dialog_open,
       !is_nil(socket.assigns.group.current_image_url)
     )}
  end

  @impl true
  def handle_event("cancel_remove_image", _params, socket) do
    {:noreply, assign(socket, :remove_image_dialog_open, false)}
  end

  @impl true
  def handle_event(
        "remove_image",
        _params,
        %{assigns: %{remove_image_dialog_open: true}} = socket
      ) do
    group = socket.assigns.group
    user = socket.assigns.current_user

    case soft_delete_all_group_images(group, user) do
      :ok ->
        {:ok, updated_group} = Ash.load(group, [:current_image_url], actor: user)

        {:noreply,
         socket
         |> put_flash(:info, "Image removed")
         |> assign(:remove_image_dialog_open, false)
         |> assign(:group, updated_group)}

      {:error, _} ->
        {:noreply,
         socket
         |> assign(:remove_image_dialog_open, false)
         |> put_flash(:error, "Failed to remove image")}
    end
  end

  def handle_event("remove_image", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("update_group", %{"form" => params}, socket) do
    params =
      params
      |> inject_group_location_param(socket.assigns.selected_location_data)

    form =
      put_provided_coordinates(
        socket.assigns.form.source,
        socket.assigns.selected_location_data
      )

    case AshPhoenix.Form.submit(form,
           params: params,
           actor: socket.assigns.current_user
         ) do
      {:ok, updated_group} ->
        assign_pending_image_to_group(socket, updated_group)

        {:noreply,
         socket
         |> put_flash(
           :info,
           "Group updated successfully. Visibility is now #{visibility_value(updated_group.is_public)}."
         )
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

  @impl true
  def handle_info({:time_zone_selected, "group-time-zone", zone_id}, socket) do
    {:noreply, apply_time_zone_to_form(socket, "time_zone", zone_id)}
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

  defp public_group?(form),
    do: Phoenix.HTML.Form.normalize_value("checkbox", form[:is_public].value)

  defp visibility_changed?(saved_public?, selected_public?),
    do: saved_public? != selected_public?

  defp visibility_label(true), do: "Public"
  defp visibility_label(false), do: "Private"

  defp visibility_value(true), do: "public"
  defp visibility_value(false), do: "private"

  defp visibility_description(true),
    do: "Anyone can find and join this group. Its public huddlz are visible without signing in."

  defp visibility_description(false),
    do: "Access is limited to current members and platform admins for this group and its huddlz."

  defp visibility_consequence(saved_public?, saved_public?),
    do:
      "No visibility change pending. Saving keeps this group #{visibility_value(saved_public?)}."

  defp visibility_consequence(true, false),
    do:
      "When you save, this group and all existing huddlz will leave public discovery. Current members keep their memberships."

  defp visibility_consequence(false, true),
    do:
      "When you save, this group and otherwise-public huddlz will become discoverable again. Current members keep their memberships."

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
