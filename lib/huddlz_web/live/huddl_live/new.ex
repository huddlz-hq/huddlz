defmodule HuddlzWeb.HuddlLive.New do
  @moduledoc """
  LiveView for creating a new huddl within a group.
  """
  use HuddlzWeb, :live_view

  import HuddlzWeb.Components.HuddlForm
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
    |> assign(:calculated_end_time, calculate_end_time(tomorrow, default_time, 60))
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
      sidebar_owned_groups={@sidebar_owned_groups}
      active="my-groups"
    >
      <div class="page-head">
        <div>
          <h1>Schedule a huddl</h1>
          <p>
            Creating a huddl for <strong>{@group.name}</strong>. Members get an email when you publish.
          </p>
        </div>
      </div>

      <.form for={@form} id="huddl-form" phx-change="validate" phx-submit="save">
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
                <.input
                  field={@form[:date]}
                  type="date"
                  label="Date"
                  min={Date.utc_today() |> Date.to_iso8601()}
                />
              </div>
              <div class="form-col-sm">
                <.input field={@form[:start_time]} type="time" label="Start time" />
              </div>
              <div class="form-col-sm">
                <.select
                  field={@form[:duration_minutes]}
                  label="Duration"
                  prompt="Select duration…"
                  options={duration_options()}
                />
              </div>
            </div>

            <p :if={@calculated_end_time} class="form-help">
              Ends at: <strong>{@calculated_end_time}</strong>
            </p>

            <div class="form-row">
              <label class="toggle">
                <input type="hidden" name={@form[:is_recurring].name} value="false" />
                <input
                  id={@form[:is_recurring].id}
                  type="checkbox"
                  name={@form[:is_recurring].name}
                  value="true"
                  checked={Phoenix.HTML.Form.normalize_value("checkbox", @form[:is_recurring].value)}
                />
                <span class="track"></span>
                <span class="toggle-text">Recurring huddl</span>
              </label>
              <p class="form-help">Repeats on a schedule until you stop it.</p>
            </div>

            <%= if Phoenix.HTML.Form.normalize_value("checkbox", @form[:is_recurring].value) do %>
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
                  new_location_path={~p"/groups/#{@group.slug}/huddlz/new/locations/new"}
                />
                <.field_errors field={@form[:physical_location]} />
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

            <%= if @group.is_public do %>
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

        <div class="panel">
          <div class="panel-head">
            <h2>Cover image</h2>
          </div>

          <label for={@uploads.huddl_image.ref} class="sr-only">Cover image</label>
          <.live_file_input upload={@uploads.huddl_image} class="hidden" />

          <%= if @pending_preview_url do %>
            <div class="image-preview" phx-drop-target={@uploads.huddl_image.ref}>
              <div
                class="card-cover"
                style={"background-image: url('#{@pending_preview_url}')"}
              >
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
          <% else %>
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
              <div class="upload-meta muted">JPG, PNG, WebP · 5 MB max · optional</div>
            </div>

            <%= for entry <- @uploads.huddl_image.entries do %>
              <div class="image-preview" style="margin-top:12px">
                <div class="card-cover">
                  <.live_img_preview entry={entry} class="card-cover-img" />
                </div>
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

              <%= for err <- upload_errors(@uploads.huddl_image, entry) do %>
                <p class="form-error">{upload_error_to_string(err)}</p>
              <% end %>
            <% end %>
          <% end %>

          <p :if={@image_error} class="form-error">{@image_error}</p>

          <%= for err <- upload_errors(@uploads.huddl_image) do %>
            <p class="form-error">{upload_error_to_string(err)}</p>
          <% end %>
        </div>

        <div class="form-foot is-flush">
          <.button variant={:primary} type="submit" phx-disable-with="Scheduling…">
            Schedule huddl
          </.button>
          <.button variant={:secondary} navigate={~p"/groups/#{@group.slug}"}>Cancel</.button>
        </div>
      </.form>

      <.modal
        :if={@live_action == :new_location}
        id="new-location-modal"
        show
        on_cancel={JS.patch(~p"/groups/#{@group.slug}/huddlz/new")}
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
            <.button variant={:secondary} patch={~p"/groups/#{@group.slug}/huddlz/new"}>
              Cancel
            </.button>
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
      |> Map.put("group_id", socket.assigns.group.id)
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
         |> put_flash(:info, "Huddl created successfully!")
         |> redirect(to: success_redirect_path(socket, huddl))}

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

  defp assign_pending_image_to_huddl(socket, huddl) do
    case socket.assigns[:pending_image_id] do
      nil ->
        :ok

      image_id ->
        with {:ok, image} <- Communities.get_huddl_image_by_id(image_id) do
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

  defp success_redirect_path(socket, _huddl) do
    ~p"/groups/#{socket.assigns.group.slug}"
  end

  defp new_huddl_path(socket) do
    ~p"/groups/#{socket.assigns.group.slug}/huddlz/new"
  end
end
