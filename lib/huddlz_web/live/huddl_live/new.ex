defmodule HuddlzWeb.HuddlLive.New do
  @moduledoc """
  LiveView for creating a new huddl within a group.
  """
  use HuddlzWeb, :live_view

  import HuddlzWeb.Components.HuddlForm
  import HuddlzWeb.Components.UploadComponents
  import HuddlzWeb.HuddlLive.FormHelpers
  import HuddlzWeb.Live.Helpers.UploadHelpers

  alias Huddlz.Communities
  alias Huddlz.Communities.Huddl
  alias Huddlz.Storage.HuddlImages
  alias HuddlzWeb.Layouts
  alias HuddlzWeb.Live.Helpers.ImageUploadPipeline
  alias HuddlzWeb.Live.Helpers.ModalLocationHelpers

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_required}
  on_mount {HuddlzWeb.LiveUserAuth, :app}

  @impl true
  def mount(%{"group_slug" => group_slug}, _session, socket) do
    user = socket.assigns.current_user

    with {:ok, group} <- get_group_by_slug(group_slug, user),
         :ok <- authorize({Huddl, :create, %{group_id: group.id}}, user) do
      {:ok, init_create_form_socket(socket, group, user)}
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
           message: "You don't have permission to create huddlz for this group",
           resource_path: ~p"/groups/#{group_slug}"
         )}
    end
  end

  defp init_create_form_socket(socket, group, user) do
    socket
    |> assign_create_form(group, user)
    |> assign(:group_locations, load_group_locations(group.id, user))
    |> assign(:selected_location, nil)
    |> ModalLocationHelpers.init()
    |> assign(:image_error, nil)
    |> assign(:pending_image_id, nil)
    |> assign(:pending_preview_url, nil)
    |> assign(:upload_processing, false)
    |> maybe_allow_image_upload()
  end

  defp maybe_allow_image_upload(%{assigns: %{uploads: %{huddl_image: _}}} = socket), do: socket

  defp maybe_allow_image_upload(socket) do
    allow_image_upload(socket, :huddl_image, &handle_upload_progress/3)
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
          "date" => Date.to_iso8601(tomorrow),
          "start_time" => Time.to_iso8601(default_time) |> String.slice(0..4),
          "duration_minutes" => "60"
        }
      )

    socket
    |> assign(:page_title, "Schedule a huddl")
    |> assign(:group, group)
    |> assign(:form, to_form(form))
    |> assign(:show_virtual_link, false)
    |> assign(:show_physical_location, true)
    |> assign(
      :calculated_end_time,
      calculate_end_time(tomorrow, default_time, 60, preview_time_zone(socket, %{}))
    )
  end

  # The zone the huddl will actually be saved in, as best known while the form
  # is still being filled in: the organizer's explicit pick if they made one,
  # else the browser-detected zone. Geo-derivation from the (not-yet-geocoded)
  # address can't be known client-side, so the browser zone is the closest
  # stand-in; `ResolveTimeZone` has the final say on submit.
  defp preview_time_zone(socket, params) do
    case params["time_zone_selection"] do
      picked when is_binary(picked) and picked != "" -> picked
      _ -> socket.assigns[:browser_time_zone] || "Etc/UTC"
    end
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    socket =
      if socket.assigns.live_action == :new_location do
        ModalLocationHelpers.clear(socket)
      else
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

  defp process_eager_upload(socket),
    do: ImageUploadPipeline.process_eager_upload(socket, upload_config())

  defp cleanup_pending_image(socket),
    do: ImageUploadPipeline.cleanup_pending_image(socket, upload_config())

  defp upload_config do
    %{
      upload_name: :huddl_image,
      storage: HuddlImages,
      create_pending: &create_pending_huddl_image/3,
      cleanup: &soft_delete_pending_huddl_image/2
    }
  end

  defp create_pending_huddl_image(socket, entry, metadata) do
    Communities.create_pending_huddl_image(
      socket.assigns.group.id,
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

  defp soft_delete_pending_huddl_image(socket, image_id) do
    with {:ok, image} <- Communities.get_huddl_image_by_id(image_id),
         true <- is_nil(image.huddl_id) do
      Communities.soft_delete_huddl_image(image, actor: socket.assigns.current_user)
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
      <div class="page-head">
        <div>
          <h1>Schedule a huddl</h1>
          <p>
            Creating a huddl for <strong>{@group.name}</strong>. Save privately while you prepare,
            or publish when it is ready for members.
          </p>
        </div>
      </div>

      <.form for={@form} id="huddl-form" phx-change="validate" phx-submit="save">
        <.cover_image_panel
          upload={@uploads.huddl_image}
          image_error={@image_error}
          optional
        >
          <:preview :if={@pending_preview_url} hide_upload_zone>
            <div class="image-preview" phx-drop-target={@uploads.huddl_image.ref}>
              <div class="card-cover" style={"background-image: url('#{@pending_preview_url}')"}>
              </div>
              <div
                class="muted"
                style="display:flex; justify-content:space-between; align-items:center; font-size:12px; margin-top:10px"
              >
                <span>Image uploaded · ready to publish.</span>
                <div style="display:flex; gap:8px">
                  <label for={@uploads.huddl_image.ref} class="btn-secondary" style="cursor:pointer">
                    Replace
                  </label>
                  <.button variant={:muted} type="button" phx-click="cancel_pending_image">
                    Remove
                  </.button>
                </div>
              </div>
            </div>
          </:preview>
        </.cover_image_panel>

        <.basics_panel form={@form} />

        <.format_panel form={@form} />

        <.live_component
          module={HuddlzWeb.Live.TimeZoneSelect}
          id="huddl-time-zone"
          field={@form[:time_zone_selection]}
          label="Time zone"
          prompt="Auto-detect from location…"
          help="Leave blank to use the location's time zone (or your current time zone for a virtual huddl)."
        />

        <.when_panel
          form={@form}
          calculated_end_time={@calculated_end_time}
          duration_prompt="Select duration…"
        >
          <:recurring_controls>
            <div class="form-row">
              <.toggle field={@form[:is_recurring]} label="Recurring huddl" />
              <p class="form-help">Repeats on a schedule until you stop it.</p>
            </div>

            <%= if Phoenix.HTML.Form.normalize_value("checkbox", @form[:is_recurring].value) do %>
              <div class="form-row form-row-inline">
                <div class="form-col-md">
                  <.select
                    field={@form[:frequency]}
                    label="Frequency"
                    options={[
                      {"Weekly", "weekly"},
                      {"Every two weeks", "every_two_weeks"},
                      {"Monthly", "monthly"}
                    ]}
                  />
                </div>
                <div class="form-col-md">
                  <.input
                    field={@form[:repeat_until]}
                    type="date"
                    label="Repeat until"
                  />
                </div>
              </div>
            <% end %>
          </:recurring_controls>
        </.when_panel>

        <.where_panel
          form={@form}
          show_physical_location={@show_physical_location}
          show_virtual_link={@show_virtual_link}
          group_locations={@group_locations}
          selected_location={@selected_location}
          new_location_path={~p"/groups/#{@group.slug}/huddlz/new/locations/new"}
        />

        <.capacity_panel form={@form} is_public={@group.is_public} />

        <div class="form-foot is-flush">
          <.button
            id="publish-huddl"
            variant={:primary}
            type="submit"
            name="intent"
            value="publish"
            phx-disable-with="Publishing…"
          >
            Schedule huddl
          </.button>
          <.button
            id="save-huddl-draft"
            variant={:secondary}
            type="submit"
            name="intent"
            value="draft"
            phx-disable-with="Saving…"
          >
            Save as draft
          </.button>
          <.button variant={:muted} navigate={~p"/groups/#{@group.slug}"}>Cancel</.button>
        </div>
      </.form>

      <.location_modal
        live_action={@live_action}
        cancel_path={~p"/groups/#{@group.slug}/huddlz/new"}
        modal_location_address={@modal_location_address}
        modal_location_name={@modal_location_name}
      />
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
    params =
      params
      |> inject_saved_location_params(socket.assigns[:selected_location])
      |> mark_location_used_after_submit(socket.assigns.form)

    socket =
      socket
      |> update_event_type_visibility(params)
      |> update_calculated_end_time(params, preview_time_zone(socket, params))

    form = AshPhoenix.Form.validate(socket.assigns.form, params)
    {:noreply, assign(socket, :form, to_form(form))}
  end

  @impl true
  def handle_event("save", %{"form" => params} = event_params, socket) do
    lifecycle_state =
      if event_params["intent"] == "draft", do: "draft", else: "published"

    params =
      params
      |> Map.put("browser_time_zone", socket.assigns.browser_time_zone)
      |> Map.put("group_id", socket.assigns.group.id)
      |> Map.put("lifecycle_state", lifecycle_state)
      |> inject_saved_location_params(socket.assigns[:selected_location])
      |> mark_location_used(socket.assigns.form)

    form =
      put_provided_coordinates(socket.assigns.form.source, socket.assigns[:selected_location])

    case AshPhoenix.Form.submit(form,
           params: params,
           actor: socket.assigns.current_user,
           before_submit: prepare_source_for_submit(socket.assigns[:pending_image_id])
         ) do
      {:ok, huddl} ->
        {message, path} =
          case huddl.lifecycle_state do
            :draft ->
              {"Draft saved. Publish it when you are ready.",
               ~p"/groups/#{socket.assigns.group.slug}/huddlz/#{huddl.id}"}

            :published ->
              {"Huddl created successfully!", ~p"/groups/#{socket.assigns.group.slug}"}
          end

        {:noreply,
         socket
         |> put_flash(:info, message)
         |> redirect(to: path)}

      {:error, form} ->
        {:noreply, assign(socket, :form, to_form(form))}
    end
  end

  @impl true
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
         |> push_patch(to: new_huddl_path(socket))}

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
  def handle_info({:saved_location_selected, "saved-location-picker", location}, socket) do
    {:noreply, apply_saved_location_to_form(socket, location)}
  end

  @impl true
  def handle_info({:saved_location_cleared, "saved-location-picker"}, socket) do
    {:noreply, clear_saved_location(socket)}
  end

  @impl true
  def handle_info({:location_selected, "modal-address-autocomplete", payload}, socket) do
    {:noreply, ModalLocationHelpers.apply_selected(socket, payload)}
  end

  @impl true
  def handle_info({:location_cleared, "modal-address-autocomplete"}, socket) do
    {:noreply, ModalLocationHelpers.clear(socket)}
  end

  @impl true
  def handle_info({:time_zone_selected, "huddl-time-zone", zone_id}, socket) do
    {:noreply, apply_huddl_time_zone_selection(socket, zone_id)}
  end

  @impl true
  def handle_info({:time_zone_cleared, "huddl-time-zone"}, socket) do
    {:noreply, apply_huddl_time_zone_selection(socket, nil)}
  end

  defp apply_huddl_time_zone_selection(socket, zone_id) do
    current_params = socket.assigns.form.source.params || %{}
    updated_params = Map.put(current_params, "time_zone_selection", zone_id || "")

    socket
    |> update_calculated_end_time(updated_params, preview_time_zone(socket, updated_params))
    |> assign(
      :form,
      socket.assigns.form.source |> AshPhoenix.Form.validate(updated_params) |> to_form()
    )
  end

  defp prepare_source_for_submit(pending_image_id) do
    fn changeset -> maybe_set_pending_image(changeset, pending_image_id) end
  end

  defp maybe_set_pending_image(changeset, nil), do: changeset

  defp maybe_set_pending_image(changeset, pending_image_id),
    do: Ash.Changeset.set_argument(changeset, :pending_image_id, pending_image_id)

  defp get_group_by_slug(slug, actor) do
    case Huddlz.Communities.get_by_slug(slug, actor: actor, load: [:owner]) do
      {:ok, nil} -> {:error, :not_found}
      {:ok, group} -> {:ok, group}
      {:error, _} -> {:error, :not_found}
    end
  end

  defp new_huddl_path(socket) do
    ~p"/groups/#{socket.assigns.group.slug}/huddlz/new"
  end
end
