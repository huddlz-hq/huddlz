defmodule HuddlzWeb.GroupLive.New do
  @moduledoc """
  LiveView for creating a new group.
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
  alias Huddlz.Communities.Group
  alias Huddlz.Communities.GroupImage
  alias Huddlz.Storage.GroupImages
  alias HuddlzWeb.Layouts
  alias HuddlzWeb.Live.Helpers.ImageUploadPipeline

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_required}
  on_mount {HuddlzWeb.LiveUserAuth, :app}

  @impl true
  def mount(_params, _session, socket) do
    if Ash.can?({Group, :create_group}, socket.assigns.current_user) do
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
       |> assign(:upload_processing, false)
       |> allow_image_upload(:group_image, &handle_upload_progress/3)}
    else
      {:ok,
       socket
       |> put_flash(:error, "You need to be logged in to create groups")
       |> redirect(to: ~p"/discover?#{[scope: "groups"]}")}
    end
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
  def handle_event("save", params, socket) do
    form_params = Map.get(params, "form", params)

    params_with_owner =
      form_params
      |> Map.put("owner_id", socket.assigns.current_user.id)
      |> inject_group_location_param(socket.assigns.selected_location_data)

    case socket.assigns.form.source
         |> AshPhoenix.Form.validate(params_with_owner)
         |> AshPhoenix.Form.submit(
           params: params_with_owner,
           actor: socket.assigns.current_user,
           before_submit: prepare_source_with_coordinates(socket.assigns.selected_location_data)
         ) do
      {:ok, group} ->
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
        with {:ok, image} <- Ash.get(GroupImage, image_id) do
          Communities.assign_group_image_to_group(image, group.id,
            actor: socket.assigns.current_user
          )
        end
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
          <h1>Create a group</h1>
          <p>
            Groups are where huddlz live. Set the name, decide who can see it, and you can invite members or schedule your first huddl in a minute.
          </p>
        </div>
      </div>

      <.form for={@form} id="group-form" phx-change="validate" phx-submit="save">
        <div class="panel">
          <div class="panel-head">
            <h2>The basics</h2>
          </div>
          <div class="form-grid">
            <.input
              field={@form[:name]}
              label="Group name"
              placeholder="e.g. Phoenix Elixir Meetup"
              autocomplete="off"
              help="3–100 characters."
            />
            <div class="form-row">
              <div class="form-help">
                URL: {url(~p"/groups/#{@form[:slug].value || "..."}")}
              </div>
            </div>
            <.textarea
              field={@form[:description]}
              label="Description"
              placeholder="Tell people what your group is about, what huddlz to expect, and who should join."
              help="Up to 5,000 characters."
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
                placeholder="Search for a city"
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
            <h2>Cover image</h2>
          </div>

          <label for={@uploads.group_image.ref} class="sr-only">Cover image</label>
          <.live_file_input upload={@uploads.group_image} class="hidden" />

          <%= if @pending_preview_url do %>
            <div class="image-preview" phx-drop-target={@uploads.group_image.ref}>
              <div
                class="card-cover"
                style={"height:140px; background-image: url('#{@pending_preview_url}')"}
              >
              </div>
              <div
                class="muted"
                style="display:flex; justify-content:space-between; align-items:center; font-size:12px; margin-top:10px"
              >
                <span>Image uploaded · ready to publish.</span>
                <div style="display:flex; gap:8px">
                  <label for={@uploads.group_image.ref} class="btn-secondary" style="cursor:pointer">
                    Replace
                  </label>
                  <.button variant={:muted} type="button" phx-click="cancel_pending_image">
                    Remove
                  </.button>
                </div>
              </div>
            </div>
          <% else %>
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
              <div class="image-preview" style="margin-top:12px">
                <.live_img_preview entry={entry} class="card-cover-img" />
                <div
                  class="muted"
                  style="display:flex; justify-content:space-between; align-items:center; font-size:12px; margin-top:10px"
                >
                  <span>{entry.client_name} · {entry.progress}%</span>
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

        <div class="form-foot" style="border:0; margin:0">
          <.button variant={:primary} type="submit" phx-disable-with="Creating…">
            Create group
          </.button>
          <.button variant={:secondary} navigate={~p"/my-groups"}>Cancel</.button>
        </div>
      </.form>
    </Layouts.app>
    """
  end
end
