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
  alias Huddlz.Communities.Huddl.CopySuggestion
  alias Huddlz.Storage.HuddlCoverImages
  alias HuddlzWeb.FormFocus
  alias HuddlzWeb.Layouts
  alias HuddlzWeb.Live.Helpers.ImageUploadPipeline

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_required}
  on_mount {HuddlzWeb.LiveUserAuth, :app}
  on_mount {HuddlzWeb.LiveUserAuth, :confirmed_user_required}

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
    |> assign(:image_error, nil)
    |> assign(:pending_image_id, nil)
    |> assign(:pending_preview_url, nil)
    |> assign(:upload_processing, false)
    |> assign(:copy_source, nil)
    |> assign(:copy_cover?, false)
    |> maybe_allow_image_upload()
  end

  defp maybe_allow_image_upload(%{assigns: %{uploads: %{huddl_cover_image: _}}} = socket),
    do: socket

  defp maybe_allow_image_upload(socket) do
    allow_image_upload(socket, :huddl_cover_image, &handle_upload_progress/3)
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

  # `?copy=<huddl id>` fills the form from another huddl of this group. Nothing
  # is saved until the organizer submits; an id they can't copy from leaves
  # the form empty. Later patches (the location modal) drop the param but
  # keep the copy.
  @impl true
  def handle_params(%{"copy" => id}, _uri, %{assigns: %{copy_source: nil}} = socket)
      when is_binary(id) do
    case fetch_copy_source(id, socket.assigns.group, socket.assigns.current_user) do
      {:ok, source} -> {:noreply, assign_copy(socket, source)}
      :error -> {:noreply, socket}
    end
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  defp fetch_copy_source(id, %{id: group_id}, user) do
    with {:ok, _uuid} <- Ecto.UUID.cast(id),
         {:ok, %Huddl{group_id: ^group_id} = source} <-
           Communities.get_huddl(id, actor: user, load: [:current_image_url, :huddl_template]) do
      {:ok, source}
    else
      _not_copyable -> :error
    end
  end

  defp assign_copy(socket, source) do
    local_starts_at = DateTime.shift_zone!(source.starts_at, source.time_zone)
    date = CopySuggestion.date(source)
    start_time = DateTime.to_time(local_starts_at)
    duration = DateTime.diff(source.ends_at, source.starts_at, :minute)

    location =
      Enum.find(socket.assigns.group_locations, &(&1.id == source.group_location_id))

    params = %{
      "copied_from_id" => source.id,
      "group_id" => source.group_id,
      "title" => source.title,
      "description" => source.description || "",
      "event_type" => to_string(source.event_type),
      "virtual_link" => source.virtual_link || "",
      "max_attendees" => if(source.max_attendees, do: to_string(source.max_attendees), else: ""),
      "is_private" => to_string(source.is_private),
      "date" => Date.to_iso8601(date),
      "start_time" => Calendar.strftime(start_time, "%H:%M"),
      "duration_minutes" => to_string(duration),
      "group_location_id" => location && location.id
    }

    # Validating right away shows a removed location's error as the form opens.
    form = AshPhoenix.Form.validate(socket.assigns.form.source, params)

    socket
    |> assign(:copy_source, source)
    |> assign(:copy_cover?, not is_nil(source.current_image_url))
    |> assign(:selected_location, location)
    |> assign(:form, to_form(form))
    |> update_event_type_visibility(params)
    |> assign(:calculated_end_time, calculate_end_time(date, start_time, duration))
  end

  defp handle_upload_progress(:huddl_cover_image, entry, socket) do
    if entry.done? do
      {:noreply, ImageUploadPipeline.start_eager_upload(socket, upload_config(socket))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_async(:prepare_cover, result, socket) do
    {:noreply, ImageUploadPipeline.finish_eager_upload(socket, result, upload_config(socket))}
  end

  defp cleanup_pending_image(socket),
    do: ImageUploadPipeline.cleanup_pending_image(socket, upload_config(socket))

  # The pending cover belongs to the group before it belongs to a huddl.
  defp upload_config(socket) do
    group_id = socket.assigns.group.id

    %{
      upload_name: :huddl_cover_image,
      storage: HuddlCoverImages,
      create_pending: &create_pending_huddl_cover_image(group_id, &1, &2, &3),
      cleanup: &soft_delete_pending_huddl_cover_image/2
    }
  end

  defp create_pending_huddl_cover_image(group_id, actor, entry, metadata) do
    Communities.create_pending_huddl_cover_image(
      group_id,
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

  defp soft_delete_pending_huddl_cover_image(socket, image_id) do
    with {:ok, image} <- Communities.get_huddl_cover_image_by_id(image_id),
         true <- is_nil(image.huddl_id) do
      Communities.soft_delete_huddl_cover_image(image, actor: socket.assigns.current_user)
    end
  end

  @impl true
  def render(assigns) do
    time_zone = schedule_time_zone(assigns.form, assigns.selected_location, assigns.group)

    assigns =
      assigns
      |> assign(:schedule_time_zone, time_zone)
      |> assign(:ambiguous_time_label, ambiguous_time_label(assigns.form, time_zone))

    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      unread_notification_count={@unread_notification_count}
      sidebar_owned_groups={@sidebar_owned_groups}
      active_group_slug={@group.slug}
      active_organize_section={:huddlz}
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

      <.copy_notice :if={@copy_source} source={@copy_source} />

      <.form for={@form} id="huddl-form" phx-change="validate" phx-submit="save">
        <.input :if={@copy_source} field={@form[:copied_from_id]} type="hidden" />

        <.cover_image_panel
          id="huddl-cover-upload"
          upload={@uploads.huddl_cover_image}
          image_url={cover_url(assigns)}
          caption={cover_caption(assigns)}
          processing?={@upload_processing}
          image_error={@image_error}
          optional
        >
          <:actions>
            <.cover_slot_button phx-click="cancel_pending_image">Remove</.cover_slot_button>
          </:actions>
        </.cover_image_panel>

        <.basics_panel form={@form} />

        <.format_panel form={@form} />

        <.when_panel
          form={@form}
          calculated_end_time={@calculated_end_time}
          duration_prompt="Select duration…"
          schedule_time_zone={@schedule_time_zone}
          ambiguous_time_label={@ambiguous_time_label}
          date_help={suggested_date_help(@copy_source, @form)}
        >
          <:recurring_controls>
            <div class="form-row">
              <.toggle field={@form[:is_recurring]} label="Recurring huddl" />
              <p class="form-help">{recurring_help(@copy_source)}</p>
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

        <div class="form-foot is-flush huddl-create-actions">
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
        group={@group}
        actor={@current_user}
        live_action={@live_action}
        cancel_path={~p"/groups/#{@group.slug}/huddlz/new"}
      />
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("cancel_image_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :huddl_cover_image, ref)}
  end

  # Remove drops an uploaded cover first, then a copied one.
  @impl true
  def handle_event("cancel_pending_image", _params, %{assigns: %{pending_image_id: nil}} = socket) do
    {:noreply, assign(socket, :copy_cover?, false)}
  end

  def handle_event("cancel_pending_image", _params, socket) do
    {:noreply, cleanup_pending_image(socket)}
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    params =
      inject_saved_location_params(
        params,
        socket.assigns[:selected_location],
        socket.assigns.form
      )

    socket =
      socket
      |> update_event_type_visibility(params)
      |> update_calculated_end_time(params)

    form = AshPhoenix.Form.validate(socket.assigns.form, params)

    {:noreply,
     socket
     |> assign(:form, to_form(form))
     |> ImageUploadPipeline.drop_invalid_entries(upload_config(socket))}
  end

  @impl true
  def handle_event("save", %{"form" => params} = event_params, socket) do
    lifecycle_state =
      if event_params["intent"] == "draft", do: "draft", else: "published"

    params =
      params
      |> Map.put("group_id", socket.assigns.group.id)
      |> Map.put("lifecycle_state", lifecycle_state)
      |> put_copy_params(socket.assigns)
      |> inject_saved_location_params(
        socket.assigns[:selected_location],
        socket.assigns.form,
        :save
      )

    case AshPhoenix.Form.submit(socket.assigns.form,
           params: params,
           actor: socket.assigns.current_user,
           before_submit: &maybe_set_pending_image(&1, socket.assigns[:pending_image_id])
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
        {:noreply, socket |> assign(:form, to_form(form)) |> FormFocus.first_error("huddl-form")}
    end
  end

  @impl true
  def handle_info({:address_book_location_created, location}, socket) do
    group_locations = load_group_locations(socket.assigns.group.id, socket.assigns.current_user)

    {:noreply,
     socket
     |> assign(:group_locations, group_locations)
     |> apply_saved_location_to_form(location)
     |> push_patch(to: new_huddl_path(socket))}
  end

  def handle_info(:address_book_location_failed, socket) do
    {:noreply, put_flash(socket, :error, "Failed to save location")}
  end

  @impl true
  def handle_info({:saved_location_selected, "saved-location-picker", location}, socket) do
    {:noreply, apply_saved_location_to_form(socket, location)}
  end

  @impl true
  def handle_info({:saved_location_cleared, "saved-location-picker"}, socket) do
    {:noreply, clear_saved_location(socket)}
  end

  # The form is the whole copy: a field the organizer cleared or hid stays
  # empty instead of falling back to the source's value.
  @copied_fields ~w(description virtual_link max_attendees)

  defp put_copy_params(params, %{copy_source: nil}), do: params

  defp put_copy_params(params, %{copy_cover?: copy_cover?}) do
    @copied_fields
    |> Enum.reduce(params, &Map.put_new(&2, &1, nil))
    |> Map.put("copy_cover", to_string(copy_cover?))
  end

  defp cover_url(%{pending_preview_url: url}) when is_binary(url), do: url

  defp cover_url(%{copy_cover?: true, copy_source: source}),
    do: HuddlCoverImages.url(source.current_image_url)

  defp cover_url(_assigns), do: nil

  defp cover_caption(%{pending_preview_url: url}) when is_binary(url),
    do: "Image uploaded · ready to publish."

  defp cover_caption(%{copy_cover?: true, copy_source: source}),
    do: "A copy of the #{short_date(source)} cover. Changing it here leaves the original alone."

  defp cover_caption(_assigns), do: nil

  attr :source, Huddl, required: true

  defp copy_notice(assigns) do
    ~H"""
    <div id="copy-notice" class="copy-notice" role="status">
      <span class="copy-notice-icon" aria-hidden="true">
        <.icon name="hero-document-duplicate" class="size-5" />
      </span>
      <div>
        <h2>Copied from “{@source.title}”</h2>
        <p>
          Everything from the {Calendar.strftime(local_date(@source), "%a, %b %-d")} huddl is filled in. Pick a date and check the details.
        </p>
        <p class="copy-notice-aside">RSVPs, photos and turnout stay with the original.</p>
      </div>
    </div>
    """
  end

  defp suggested_date_help(nil, _form), do: nil

  defp suggested_date_help(source, form) do
    suggested = CopySuggestion.date(source)

    if Phoenix.HTML.Form.input_value(form, :date) in [suggested, Date.to_iso8601(suggested)] do
      "Suggested: the next #{Calendar.strftime(suggested, "%A")}."
    end
  end

  defp recurring_help(%Huddl{huddl_template: %{} = template} = source) do
    "Copied as a one-off. The #{short_date(source)} huddl was part of #{series_phrase(template)}."
  end

  defp recurring_help(_source), do: "Repeats on a schedule until you stop it."

  defp series_phrase(%{interval: 1, unit: :week}), do: "a weekly series"
  defp series_phrase(%{interval: 1, unit: :month}), do: "a monthly series"
  defp series_phrase(%{interval: n, unit: unit}), do: "a series every #{n} #{unit}s"

  defp short_date(source), do: Calendar.strftime(local_date(source), "%b %-d")

  defp local_date(huddl),
    do: huddl.starts_at |> DateTime.shift_zone!(huddl.time_zone) |> DateTime.to_date()

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
