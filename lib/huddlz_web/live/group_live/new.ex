defmodule HuddlzWeb.GroupLive.New do
  @moduledoc """
  LiveView for creating a new group.
  """
  use HuddlzWeb, :live_view

  import HuddlzWeb.Components.UploadComponents
  import HuddlzWeb.Live.Helpers.UploadHelpers

  import HuddlzWeb.HuddlLive.FormHelpers,
    only: [
      inject_group_location_param: 2,
      apply_group_location_to_form: 2,
      mark_untouched_group_location: 2
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
      {:noreply, ImageUploadPipeline.start_eager_upload(socket, upload_config())}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_async(:prepare_cover, result, socket) do
    {:noreply, ImageUploadPipeline.finish_eager_upload(socket, result, upload_config())}
  end

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

  defp create_pending_group_image(actor, entry, metadata) do
    Communities.create_pending_group_image(
      %{
        filename: entry.client_name,
        content_type: entry.client_type,
        size_bytes: metadata.size_bytes,
        storage_path: metadata.storage_path,
        thumbnail_path: metadata.thumbnail_path
      },
      actor: actor
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
    params = mark_untouched_group_location(params, socket.assigns.selected_location_data)

    form =
      socket.assigns.form.source
      |> AshPhoenix.Form.validate(params)

    {:noreply,
     socket
     |> assign(:form, to_form(form))
     |> ImageUploadPipeline.drop_invalid_entries(upload_config())}
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
           actor: socket.assigns.current_user
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
      longitude: payload.longitude,
      time_zone: payload.time_zone
    }

    {:noreply,
     socket
     |> assign(:selected_location_data, location_data)
     |> apply_group_location_to_form(location_data)}
  end

  @impl true
  def handle_info({:location_cleared, "group-location"}, socket) do
    {:noreply,
     socket
     |> assign(:selected_location_data, nil)
     |> apply_group_location_to_form(nil)}
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
      unread_notification_count={@unread_notification_count}
      sidebar_owned_groups={@sidebar_owned_groups}
      active="groups"
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
            <div id="group-slug-preview" class="form-row">
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
              <.field_errors field={@form[:location]} />
              <p class="form-help">
                Required. This city sets the group time zone and helps people find it nearby.
              </p>
            </div>
          </div>
        </div>

        <div class="panel">
          <div class="panel-head">
            <div>
              <h2>Cover image</h2>
              <div class="panel-sub">
                Optional. Shown on the group card and at the top of the group page.
              </div>
            </div>
          </div>
          <.cover_upload
            id="group-cover-upload"
            upload={@uploads.group_image}
            image_url={@pending_preview_url}
            caption="Image uploaded · ready to publish."
            processing?={@upload_processing}
            image_error={@image_error}
            optional
          >
            <:actions>
              <.cover_slot_button phx-click="cancel_pending_image">Remove</.cover_slot_button>
            </:actions>
          </.cover_upload>
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
                <label class="row-title" for={@form[:is_public].id}>Public group</label>
                <div class="row-desc">
                  Anyone can find and join this group. Huddlz are visible without signing in.
                </div>
              </div>
              <.toggle
                field={@form[:is_public]}
                label="Public group"
                show_state_text
                labelled_externally
              />
            </div>
          </div>
        </div>

        <div class="form-foot" style="border:0; margin:0">
          <.button variant={:primary} type="submit" phx-disable-with="Creating…">
            Create group
          </.button>
          <.button variant={:secondary} navigate={~p"/groups"}>Cancel</.button>
        </div>
      </.form>
    </Layouts.app>
    """
  end
end
