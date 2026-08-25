defmodule HuddlzWeb.HuddlLive.Edit do
  @moduledoc """
  LiveView for editing an existing huddl's details.
  """
  use HuddlzWeb, :live_view

  import HuddlzWeb.Components.HuddlForm
  import HuddlzWeb.Components.UploadComponents
  import HuddlzWeb.HuddlLive.FormHelpers
  import HuddlzWeb.Live.Helpers.UploadHelpers

  alias Huddlz.Communities
  alias Huddlz.Communities.HuddlTemplate
  alias Huddlz.Storage.GroupImages
  alias Huddlz.Storage.HuddlImages
  alias HuddlzWeb.Layouts
  alias HuddlzWeb.Live.Helpers.ImageUploadPipeline
  alias HuddlzWeb.Live.Helpers.ModalLocationHelpers

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_required}
  on_mount {HuddlzWeb.LiveUserAuth, :app}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"group_slug" => group_slug, "id" => id}, _, socket) do
    if socket.assigns[:huddl] && socket.assigns.huddl.id == id do
      {:noreply, apply_modal_state(socket)}
    else
      load_huddl(socket, group_slug, id)
    end
  end

  defp load_huddl(socket, group_slug, id) do
    user = socket.assigns.current_user

    with {:ok, huddl} <- get_huddl(id, group_slug, user),
         :ok <- authorize({huddl, :update}, user) do
      group_locations = load_group_locations(huddl.group.id, user)

      socket =
        socket
        |> assign_edit_form(huddl, group_slug, user)
        |> assign(:group_locations, group_locations)
        |> assign(:selected_location, find_matching_location(huddl, group_locations))
        |> ModalLocationHelpers.init()
        |> assign(:image_error, nil)
        |> assign(:pending_image_id, nil)
        |> assign(:pending_preview_url, nil)
        |> assign(:upload_processing, false)
        |> allow_image_upload(:huddl_image, &handle_upload_progress/3)

      {:noreply, socket}
    else
      {:error, :not_found} ->
        {:noreply,
         handle_error(socket, :not_found,
           resource_name: "Huddl",
           fallback_path: ~p"/groups/#{group_slug}"
         )}

      {:error, :not_authorized} ->
        {:noreply,
         handle_error(socket, :not_authorized,
           resource_name: "huddl",
           action: "edit",
           resource_path: ~p"/groups/#{group_slug}/huddlz/#{id}"
         )}
    end
  end

  defp apply_modal_state(socket) do
    case socket.assigns.live_action do
      :new_location -> ModalLocationHelpers.clear(socket)
      _ -> socket
    end
  end

  defp assign_edit_form(socket, huddl, group_slug, user) do
    # Extract date/time/duration from existing starts_at/ends_at
    date = DateTime.to_date(huddl.starts_at)
    start_time = DateTime.to_time(huddl.starts_at)
    duration_minutes = DateTime.diff(huddl.ends_at, huddl.starts_at, :minute)

    form =
      AshPhoenix.Form.for_update(huddl, :update,
        domain: Huddlz.Communities,
        actor: user,
        forms: [auto?: true]
      )

    # Pre-populate virtual args from existing data
    # All params must be set in a single validate call since validate replaces params
    initial_params = %{
      "date" => Date.to_iso8601(date),
      "start_time" => Calendar.strftime(start_time, "%H:%M"),
      "duration_minutes" => to_string(duration_minutes),
      "max_attendees" => if(huddl.max_attendees, do: to_string(huddl.max_attendees), else: ""),
      "event_type" => to_string(huddl.event_type),
      "physical_location" => huddl.physical_location || "",
      "virtual_link" => huddl.virtual_link || ""
    }

    initial_params = maybe_add_recurring_params(initial_params, huddl)

    form = AshPhoenix.Form.validate(form, initial_params)

    socket
    |> assign(:page_title, huddl.title)
    |> assign(:group_slug, group_slug)
    |> assign(:huddl, huddl)
    |> assign(:show_physical_location, huddl.event_type in [:in_person, :hybrid])
    |> assign(:show_virtual_link, huddl.event_type in [:virtual, :hybrid])
    |> assign(:calculated_end_time, calculate_end_time(date, start_time, duration_minutes))
    |> assign(:form, to_form(form))
  end

  defp maybe_add_recurring_params(params, huddl) do
    if huddl.huddl_template_id do
      Map.merge(params, %{
        "repeat_until" => huddl.huddl_template.repeat_until,
        "frequency" => huddl.huddl_template |> HuddlTemplate.cadence() |> to_string()
      })
    else
      params
    end
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
      socket.assigns.huddl.group.id,
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
          <h1>Editing {@huddl.title}</h1>
          <p id="attendee-notification-explanation">
            Updates to the title, time, location, capacity, or privacy will notify affected people who've RSVP'd.
          </p>
        </div>
      </div>

      <.form for={@form} id="huddl-form" phx-change="validate" phx-submit="save">
        <%= if @huddl.huddl_template_id do %>
          <div class="panel">
            <div class="edit-scope-row">
              <%= case edit_type_value(@form) do %>
                <% "all" -> %>
                  <span class="eyebrow eyebrow-warn">Editing every upcoming date</span>
                  <p>
                    Your changes apply to all upcoming dates in this series. Past instances are unchanged.
                  </p>
                <% _ -> %>
                  <span class="eyebrow">Editing one date</span>
                  <p>
                    This is a recurring huddl. Changes apply only to <strong>{Calendar.strftime(@huddl.starts_at, "%a, %b %-d")}</strong>.
                  </p>
              <% end %>
              <input
                type="hidden"
                id={@form[:edit_type].id}
                name={@form[:edit_type].name}
                value={edit_type_value(@form)}
              />
              <div class="chip-group">
                <button
                  type="button"
                  class={["chip", edit_type_value(@form) == "instance" && "is-active"]}
                  phx-click="set_edit_type"
                  phx-value-type="instance"
                >
                  Just this huddl
                </button>
                <button
                  type="button"
                  class={["chip", edit_type_value(@form) == "all" && "is-active"]}
                  phx-click="set_edit_type"
                  phx-value-type="all"
                >
                  Whole series
                </button>
              </div>
            </div>
          </div>
        <% end %>

        <.cover_image_panel upload={@uploads.huddl_image} image_error={@image_error}>
          <:preview>
            <.image_preview
              pending_preview_url={@pending_preview_url}
              huddl={@huddl}
              upload_ref={@uploads.huddl_image.ref}
            />
          </:preview>
        </.cover_image_panel>

        <.basics_panel form={@form} />

        <.format_panel form={@form} />

        <.select
          field={@form[:time_zone]}
          label="Time zone"
          options={HuddlzWeb.Live.Helpers.TimeZoneOptions.options()}
          help="Change the address to re-derive this from the new location, or pick a zone here to override it."
        />

        <.when_panel form={@form} calculated_end_time={@calculated_end_time}>
          <:recurring_controls>
            <%= if @huddl.huddl_template_id && edit_type_value(@form) == "all" do %>
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
          new_location_path={~p"/groups/#{@group_slug}/huddlz/#{@huddl.id}/edit/locations/new"}
        />

        <.capacity_panel form={@form} is_public={@huddl.group.is_public} />

        <div class="form-foot is-flush">
          <.button variant={:primary} type="submit" phx-disable-with="Saving…">
            Save changes
          </.button>
          <.button variant={:secondary} navigate={~p"/groups/#{@group_slug}/huddlz/#{@huddl.id}"}>
            Cancel
          </.button>
        </div>
      </.form>

      <.location_modal
        live_action={@live_action}
        cancel_path={~p"/groups/#{@group_slug}/huddlz/#{@huddl.id}/edit"}
        modal_location_address={@modal_location_address}
        modal_location_name={@modal_location_name}
      />
    </Layouts.app>
    """
  end

  attr :pending_preview_url, :string, default: nil
  attr :huddl, :map, required: true
  attr :upload_ref, :string, required: true

  defp image_preview(%{pending_preview_url: url} = assigns) when is_binary(url) do
    ~H"""
    <div class="image-preview" phx-drop-target={@upload_ref}>
      <div class="card-cover" style={"background-image: url('#{@pending_preview_url}')"}></div>
      <div class="image-preview-foot">
        <span>New image uploaded. Save to apply.</span>
        <div class="image-preview-actions">
          <label for={@upload_ref} class="btn-secondary" style="cursor:pointer">Replace</label>
          <.button variant={:muted} type="button" phx-click="cancel_pending_image">
            Discard
          </.button>
        </div>
      </div>
    </div>
    """
  end

  defp image_preview(%{huddl: %{current_image_url: url}} = assigns) when is_binary(url) do
    ~H"""
    <div class="image-preview">
      <div
        class="card-cover"
        style={"background-image: url('#{HuddlImages.url(@huddl.current_image_url)}')"}
      >
      </div>
      <div class="image-preview-foot">
        <span>Current image.</span>
        <div class="image-preview-actions">
          <label for={@upload_ref} class="btn-secondary" style="cursor:pointer">Replace</label>
          <.button variant={:muted} type="button" phx-click="remove_current_image">
            Remove
          </.button>
        </div>
      </div>
    </div>
    """
  end

  defp image_preview(%{huddl: %{group: %{current_image_url: url}}} = assigns)
       when is_binary(url) do
    ~H"""
    <div class="image-preview">
      <div
        class="card-cover"
        style={"background-image: url('#{GroupImages.url(@huddl.group.current_image_url)}')"}
      >
      </div>
      <div class="image-preview-foot">
        <span>Using group image — upload one specific to this huddl below.</span>
      </div>
    </div>
    """
  end

  defp image_preview(assigns), do: ~H""

  defp edit_type_value(form) do
    case AshPhoenix.Form.value(form.source, :edit_type) do
      "all" -> "all"
      _ -> "instance"
    end
  end

  @impl true
  def handle_event("set_edit_type", %{"type" => type}, socket) when type in ["instance", "all"] do
    current_params = socket.assigns.form.source.params || %{}
    updated_params = Map.put(current_params, "edit_type", type)

    socket =
      socket
      |> update_event_type_visibility(updated_params)
      |> update_calculated_end_time(updated_params)

    form = AshPhoenix.Form.validate(socket.assigns.form, updated_params)
    {:noreply, assign(socket, :form, to_form(form))}
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
  def handle_event("remove_current_image", _params, socket) do
    huddl = socket.assigns.huddl

    case Communities.get_current_huddl_image(huddl.id) do
      {:ok, image} when not is_nil(image) ->
        Communities.soft_delete_huddl_image(image, actor: socket.assigns.current_user)

        {:ok, updated_huddl} =
          get_huddl(huddl.id, socket.assigns.group_slug, socket.assigns.current_user)

        {:noreply, socket |> assign(:huddl, updated_huddl) |> put_flash(:info, "Image removed")}

      _ ->
        {:noreply, socket}
    end
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
      |> update_calculated_end_time(params)

    form = AshPhoenix.Form.validate(socket.assigns.form, params)
    {:noreply, assign(socket, :form, to_form(form))}
  end

  @impl true
  def handle_event("save", %{"form" => params}, socket) do
    params =
      params
      |> Map.put("browser_time_zone", socket.assigns.browser_time_zone)
      |> inject_saved_location_params(socket.assigns[:selected_location])
      |> mark_location_used(socket.assigns.form)

    case AshPhoenix.Form.submit(socket.assigns.form,
           params: params,
           actor: socket.assigns.current_user,
           before_submit: prepare_source_with_coordinates(socket.assigns[:selected_location])
         ) do
      {:ok, huddl} ->
        assign_pending_image_to_huddl(socket, huddl)

        {:noreply,
         socket
         |> put_flash(:info, "Huddl updated successfully!")
         |> redirect(
           to: ~p"/groups/#{socket.assigns.huddl.group.slug}/huddlz/#{socket.assigns.huddl.id}"
         )}

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
           socket.assigns.huddl.group.id,
           actor: user
         ) do
      {:ok, location} ->
        group_locations = load_group_locations(socket.assigns.huddl.group.id, user)

        {:noreply,
         socket
         |> assign(:group_locations, group_locations)
         |> apply_saved_location_to_form(location)
         |> push_patch(
           to: ~p"/groups/#{socket.assigns.group_slug}/huddlz/#{socket.assigns.huddl.id}/edit"
         )}

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

  defp assign_pending_image_to_huddl(socket, huddl) do
    case socket.assigns[:pending_image_id] do
      nil ->
        :ok

      image_id ->
        case Communities.get_current_huddl_image(huddl.id) do
          {:ok, existing} when not is_nil(existing) ->
            Communities.soft_delete_huddl_image(existing, actor: socket.assigns.current_user)

          _ ->
            :ok
        end

        with {:ok, image} <- Communities.get_huddl_image_by_id(image_id) do
          Communities.assign_huddl_image_to_huddl(image, huddl.id,
            actor: socket.assigns.current_user
          )
        end
    end
  end

  defp get_huddl(id, group_slug, user) do
    case Communities.get_huddl(id,
           actor: user,
           load: [
             :creator,
             :huddl_template,
             :status,
             :visible_virtual_link,
             :current_image_url,
             group: [:current_image_url]
           ]
         ) do
      {:ok, nil} ->
        {:error, :not_found}

      {:ok, huddl} ->
        if huddl.group.slug == group_slug do
          {:ok, huddl}
        else
          {:error, :not_found}
        end

      {:error, _} ->
        {:error, :not_found}
    end
  end

  defp find_matching_location(huddl, group_locations) do
    Enum.find(group_locations, &(&1.id == huddl.group_location_id)) ||
      find_legacy_matching_location(huddl, group_locations)
  end

  defp find_legacy_matching_location(
         %{group_location_id: nil, physical_location: address},
         locations
       )
       when not is_nil(address),
       do: Enum.find(locations, &(&1.address == address))

  defp find_legacy_matching_location(_huddl, _locations), do: nil
end
