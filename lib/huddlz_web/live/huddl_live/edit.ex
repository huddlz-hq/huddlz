defmodule HuddlzWeb.HuddlLive.Edit do
  @moduledoc """
  LiveView for editing an existing huddl's details.
  """
  use HuddlzWeb, :live_view

  import HuddlzWeb.Components.HuddlForm
  import HuddlzWeb.HuddlLive.FormHelpers
  import HuddlzWeb.Live.Helpers.UploadHelpers

  alias Huddlz.Communities
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
      "max_attendees" => if(huddl.max_attendees, do: to_string(huddl.max_attendees), else: "")
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
        "frequency" => to_string(huddl.huddl_template.frequency)
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
      sidebar_owned_groups={@sidebar_owned_groups}
      active="my-groups"
    >
      <div class="page-head">
        <div>
          <h1>Editing {@huddl.title}</h1>
          <p>
            Updates to time, location, capacity, or privacy will email everyone who's RSVP'd.
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

        <div class="panel">
          <div class="panel-head">
            <h2>Cover image</h2>
          </div>

          <label for={@uploads.huddl_image.ref} class="sr-only">Cover image</label>
          <.live_file_input upload={@uploads.huddl_image} class="hidden" />

          <.image_preview
            pending_preview_url={@pending_preview_url}
            huddl={@huddl}
            upload_ref={@uploads.huddl_image.ref}
          />

          <div class="upload-zone" phx-drop-target={@uploads.huddl_image.ref}>
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
                <rect x="3" y="3" width="18" height="18" rx="2" /><circle cx="9" cy="9" r="2" /><path d="m21 15-5-5L5 21" />
              </svg>
            </div>
            <label for={@uploads.huddl_image.ref} class="upload-prompt">
              Drop a 16:9 image, or <span class="upload-link">browse</span>
            </label>
            <div class="upload-meta muted">JPG, PNG, WebP · 5 MB max</div>
          </div>

          <%= for entry <- @uploads.huddl_image.entries do %>
            <div class="image-preview" style="margin-top:12px">
              <div class="card-cover">
                <.live_img_preview entry={entry} class="card-cover-img" />
              </div>
              <div class="image-preview-foot">
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

            <%= for err <- upload_errors(@uploads.huddl_image, entry) do %>
              <p class="form-error">{upload_error_to_string(err)}</p>
            <% end %>
          <% end %>

          <p :if={@image_error} class="form-error">{@image_error}</p>

          <%= for err <- upload_errors(@uploads.huddl_image) do %>
            <p class="form-error">{upload_error_to_string(err)}</p>
          <% end %>
        </div>

        <div class="panel">
          <div class="panel-head">
            <h2>The basics</h2>
          </div>
          <div class="form-grid">
            <.input
              field={@form[:title]}
              label="Title"
              placeholder="e.g. Ash Framework workshop"
              autocomplete="off"
            />
            <.textarea
              field={@form[:description]}
              label="Description"
              rows="4"
              placeholder="What you'll do, what to bring, who it's for."
            />
          </div>
        </div>

        <div class="panel">
          <div class="panel-head">
            <h2>Format</h2>
          </div>
          <.event_type_grid field={@form[:event_type]} />
          <.field_errors field={@form[:event_type]} />
        </div>

        <div class="panel">
          <div class="panel-head">
            <h2>When</h2>
          </div>
          <div class="form-grid">
            <div class="form-row form-row-inline">
              <div class="form-col-md">
                <.input field={@form[:date]} type="date" label="Date" />
              </div>
              <div class="form-col-sm">
                <.input field={@form[:start_time]} type="time" label="Start time" />
              </div>
              <div class="form-col-sm">
                <.select
                  field={@form[:duration_minutes]}
                  label="Duration"
                  options={duration_options()}
                />
              </div>
            </div>

            <p :if={@calculated_end_time} class="form-help">
              Ends at: <strong>{@calculated_end_time}</strong>
            </p>

            <%= if @huddl.huddl_template_id && edit_type_value(@form) == "all" do %>
              <div class="form-row form-row-inline">
                <div class="form-col-md">
                  <.select
                    field={@form[:frequency]}
                    label="Frequency"
                    options={[{"Weekly", "weekly"}, {"Monthly", "monthly"}]}
                    required
                  />
                </div>
                <div class="form-col-md">
                  <.input
                    field={@form[:repeat_until]}
                    type="date"
                    label="Repeat until"
                    required
                  />
                </div>
              </div>
            <% end %>
          </div>
        </div>

        <div class="panel">
          <div class="panel-head">
            <h2>Where</h2>
          </div>
          <div class="form-grid">
            <%= if @show_physical_location do %>
              <div class="form-row">
                <.live_component
                  module={HuddlzWeb.Live.SavedLocationPicker}
                  id="saved-location-picker"
                  group_locations={@group_locations}
                  selected_location={@selected_location}
                  new_location_path={
                    ~p"/groups/#{@group_slug}/huddlz/#{@huddl.id}/edit/locations/new"
                  }
                />
              </div>
            <% end %>

            <%= if @show_virtual_link do %>
              <.input
                field={@form[:virtual_link]}
                type="url"
                label="Online link"
                placeholder="https://meet.example.com/..."
                help="Only attendees see this link."
              />
            <% end %>
          </div>
        </div>

        <div class="panel">
          <div class="panel-head">
            <h2>Capacity &amp; visibility</h2>
          </div>
          <div class="form-grid">
            <.input
              field={@form[:max_attendees]}
              type="number"
              label="Max attendees"
              min="1"
              placeholder="No limit"
              help="Leave blank for unlimited. When full, new RSVPs go to a waitlist."
            />

            <%= if @huddl.group.is_public do %>
              <div class="form-row">
                <label class="toggle">
                  <input type="hidden" name={@form[:is_private].name} value="false" />
                  <input
                    id={@form[:is_private].id}
                    type="checkbox"
                    name={@form[:is_private].name}
                    value="true"
                    checked={Phoenix.HTML.Form.normalize_value("checkbox", @form[:is_private].value)}
                  />
                  <span class="track"></span>
                  <span class="toggle-text">Members only</span>
                </label>
                <p class="form-help">
                  Only group members can RSVP. Useful for private workshops or socials.
                </p>
              </div>
            <% else %>
              <p class="form-help">
                <.icon name="hero-lock-closed" class="h-4 w-4 inline" />
                This will be a private huddl (private groups can only create private huddlz).
              </p>
            <% end %>
          </div>
        </div>

        <div class="form-foot is-flush">
          <.button variant={:primary} type="submit" phx-disable-with="Saving…">
            Save changes
          </.button>
          <.button variant={:secondary} navigate={~p"/groups/#{@group_slug}/huddlz/#{@huddl.id}"}>
            Cancel
          </.button>
        </div>
      </.form>

      <.modal
        :if={@live_action == :new_location}
        id="new-location-modal"
        show
        on_cancel={JS.patch(~p"/groups/#{@group_slug}/huddlz/#{@huddl.id}/edit")}
      >
        <h2 class="font-display text-xl tracking-tight text-glow mb-6">Add New Address</h2>

        <form phx-submit="save_location" phx-change="modal_form_changed" class="form-grid">
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
            <label class="form-label" for="location-name-input">
              Location name (optional)
            </label>
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
              Save address
            </.button>
            <.button
              variant={:secondary}
              patch={~p"/groups/#{@group_slug}/huddlz/#{@huddl.id}/edit"}
            >
              Cancel
            </.button>
          </div>
        </form>
      </.modal>
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
    params = inject_saved_location_params(params, socket.assigns[:selected_location])

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
      if socket.assigns.huddl.group.is_public do
        params
      else
        Map.put(params, "is_private", "true")
      end

    params =
      case params["event_type"] do
        "virtual" -> Map.put(params, "physical_location", nil)
        "in_person" -> Map.put(params, "virtual_link", nil)
        _ -> params
      end

    params = inject_saved_location_params(params, socket.assigns[:selected_location])

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
    if huddl.physical_location do
      Enum.find(group_locations, fn loc -> loc.address == huddl.physical_location end)
    end
  end
end
