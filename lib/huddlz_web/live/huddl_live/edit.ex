defmodule HuddlzWeb.HuddlLive.Edit do
  @moduledoc """
  LiveView for editing an existing huddl's details.
  """
  use HuddlzWeb, :live_view
  use HuddlzWeb.HuddlLive.AddressAutocomplete

  import HuddlzWeb.HuddlLive.FormHelpers
  import HuddlzWeb.HuddlLive.FormComponent

  alias Huddlz.Communities
  alias Huddlz.Communities.Huddl
  alias Huddlz.Communities.HuddlImage
  alias Huddlz.Storage.GroupImages
  alias Huddlz.Storage.HuddlImages
  alias HuddlzWeb.Layouts

  require Ash.Query

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"group_slug" => group_slug, "id" => id}, _, socket) do
    user = socket.assigns.current_user

    with {:ok, huddl} <- get_huddl(id, group_slug, user),
         :ok <- authorize({huddl, :update}, user) do
      socket =
        socket
        |> assign_edit_form(huddl, group_slug, user)
        |> assign(:image_error, nil)
        |> assign(:pending_image_id, nil)
        |> assign(:pending_preview_url, nil)
        |> assign(:upload_processing, false)
        |> allow_upload(:huddl_image,
          accept: ~w(.jpg .jpeg .png .webp),
          max_entries: 1,
          max_file_size: 5_000_000,
          auto_upload: true,
          progress: &handle_upload_progress/3
        )

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
      "duration_minutes" => to_string(duration_minutes)
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
    |> assign_address_autocomplete()
  end

  defp maybe_add_recurring_params(params, huddl) do
    if huddl.huddl_template_id do
      Map.merge(params, %{
        "is_recurring" => "true",
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

  defp process_eager_upload(socket) do
    socket = cleanup_pending_image(socket)
    socket = assign(socket, :upload_processing, true)

    result =
      consume_uploaded_entries(socket, :huddl_image, fn %{path: path}, entry ->
        store_and_create_pending_image(
          path,
          entry,
          socket.assigns.current_user,
          socket.assigns.huddl.group.id
        )
      end)

    socket = assign(socket, :upload_processing, false)
    apply_upload_result(socket, result)
  end

  defp store_and_create_pending_image(path, entry, user, group_id) do
    with {:ok, metadata} <- HuddlImages.store_pending(path, entry.client_name, entry.client_type),
         {:ok, image} <- create_pending_image_record(entry, metadata, user, group_id) do
      {:ok, {:success, image.id, metadata.thumbnail_path}}
    else
      {:error, reason} -> {:ok, {:error, reason}}
    end
  end

  defp create_pending_image_record(entry, metadata, user, group_id) do
    Communities.create_pending_huddl_image(
      %{
        filename: entry.client_name,
        content_type: entry.client_type,
        size_bytes: metadata.size_bytes,
        storage_path: metadata.storage_path,
        thumbnail_path: metadata.thumbnail_path
      },
      group_id,
      actor: user
    )
  end

  defp apply_upload_result(socket, result) do
    case result do
      [{:success, image_id, thumbnail_path}] ->
        socket
        |> assign(:pending_image_id, image_id)
        |> assign(:pending_preview_url, HuddlImages.url(thumbnail_path))
        |> assign(:image_error, nil)

      [{:error, reason}] ->
        assign(socket, :image_error, format_upload_error(reason))

      [] ->
        socket
    end
  end

  defp cleanup_pending_image(socket) do
    case socket.assigns[:pending_image_id] do
      nil ->
        socket

      image_id ->
        with {:ok, image} <- Ash.get(HuddlImage, image_id),
             true <- is_nil(image.huddl_id) do
          Communities.soft_delete_huddl_image(image, actor: socket.assigns.current_user)
        end

        assign(socket, pending_image_id: nil, pending_preview_url: nil)
    end
  end

  defp format_upload_error(:invalid_extension),
    do: "Invalid file type. Please use JPG, PNG, or WebP"

  defp format_upload_error(msg) when is_binary(msg), do: msg
  defp format_upload_error(_), do: "Upload failed"

  defp upload_error_to_string(:too_large), do: "File is too large (max 5MB)"

  defp upload_error_to_string(:not_accepted),
    do: "Invalid file type. Please use JPG, PNG, or WebP"

  defp upload_error_to_string(:too_many_files), do: "Only one file can be uploaded at a time"
  defp upload_error_to_string(err), do: "Upload error: #{inspect(err)}"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.link
        navigate={~p"/groups/#{@group_slug}"}
        class="text-sm font-semibold leading-6 hover:underline"
      >
        <.icon name="hero-arrow-left" class="h-3 w-3" /> Back to {@huddl.group.name}
      </.link>
      <.header>
        Editing {@huddl.title}
      </.header>

      <.form for={@form} id="huddl-form" phx-change="validate" phx-submit="save" class="space-y-6">
        <.huddl_form_fields
          form={@form}
          show_physical_location={@show_physical_location}
          show_virtual_link={@show_virtual_link}
          calculated_end_time={@calculated_end_time}
          address_suggestions={@address_suggestions}
          show_address_suggestions={@show_address_suggestions}
          address_loading={@address_loading}
          address_error={@address_error}
          is_public={@huddl.group.is_public}
        >
          <:image_section>
            <div>
              <label class="mono-label text-primary/70 mb-2 block">
                Huddl Image
              </label>

              <%= cond do %>
                <% @pending_preview_url -> %>
                  <div class="mb-3 flex items-center gap-3 p-3 bg-base-200">
                    <img
                      src={@pending_preview_url}
                      class="w-32 aspect-video object-cover"
                      alt="Preview"
                    />
                    <div class="flex-1 min-w-0">
                      <p class="text-sm font-medium text-success flex items-center gap-1">
                        <.icon name="hero-check-circle" class="w-4 h-4" /> New image uploaded
                      </p>
                    </div>
                    <button
                      type="button"
                      phx-click="cancel_pending_image"
                      class="p-1 hover:bg-base-300 text-base-content/50 hover:text-base-content transition-colors"
                    >
                      <.icon name="hero-x-mark" class="w-4 h-4" />
                    </button>
                  </div>
                <% @huddl.current_image_url -> %>
                  <div class="mb-3 flex items-center gap-3 p-3 bg-base-200">
                    <img
                      src={HuddlImages.url(@huddl.current_image_url)}
                      class="w-32 aspect-video object-cover"
                      alt="Current image"
                    />
                    <div class="flex-1 min-w-0">
                      <p class="text-sm font-medium">Current image</p>
                    </div>
                    <button
                      type="button"
                      phx-click="remove_current_image"
                      class="p-1 hover:bg-base-300 text-base-content/50 hover:text-error transition-colors"
                      title="Remove image"
                    >
                      <.icon name="hero-trash" class="w-4 h-4" />
                    </button>
                  </div>
                <% @huddl.group.current_image_url -> %>
                  <div class="mb-3 flex items-center gap-3 p-3 bg-base-200/50 border border-dashed border-base-300">
                    <img
                      src={GroupImages.url(@huddl.group.current_image_url)}
                      class="w-32 aspect-video object-cover opacity-70"
                      alt="Group image"
                    />
                    <div class="flex-1 min-w-0">
                      <p class="text-sm text-base-content/50">(Using group image)</p>
                    </div>
                  </div>
                <% true -> %>
                  <div class="mb-3 flex items-center gap-3 p-3 bg-base-200/50 border border-dashed border-base-300">
                    <div class="w-32 aspect-video bg-base-100 flex items-center justify-center">
                      <.icon name="hero-photo" class="w-6 h-6 text-base-content/30" />
                    </div>
                    <div class="flex-1 min-w-0">
                      <p class="text-sm text-base-content/50">(No image)</p>
                    </div>
                  </div>
              <% end %>

              <div
                class="border border-dashed border-base-300 p-4 text-center hover:border-primary transition-colors"
                phx-drop-target={@uploads.huddl_image.ref}
              >
                <.live_file_input upload={@uploads.huddl_image} class="hidden" />
                <label
                  for={@uploads.huddl_image.ref}
                  class="cursor-pointer flex flex-col items-center"
                >
                  <.icon name="hero-arrow-up-tray" class="w-6 h-6 text-base-content/50 mb-2" />
                  <span class="text-sm text-base-content/50">
                    Upload new image
                  </span>
                  <span class="text-xs text-base-content/50 mt-1">
                    JPG, PNG, or WebP (max 5MB)
                  </span>
                </label>
              </div>

              <%= if @image_error do %>
                <p class="text-error text-sm mt-2">{@image_error}</p>
              <% end %>

              <%= for entry <- @uploads.huddl_image.entries do %>
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

                <%= for err <- upload_errors(@uploads.huddl_image, entry) do %>
                  <p class="text-error text-sm mt-1">{upload_error_to_string(err)}</p>
                <% end %>
              <% end %>

              <%= for err <- upload_errors(@uploads.huddl_image) do %>
                <p class="text-error text-sm mt-2">{upload_error_to_string(err)}</p>
              <% end %>
            </div>
          </:image_section>

          <:recurring_section>
            <%= if @huddl.huddl_template_id do %>
              <p>This is a recurring huddl. Please select which huddlz to update</p>
              <div>
                <div>
                  <input
                    id="form_edit_type_instance"
                    type="radio"
                    name="form[edit_type]"
                    class="w-4 h-4 accent-primary"
                    value="instance"
                    checked={AshPhoenix.Form.value(@form.source, :edit_type) == "instance"}
                  />
                  <label
                    class="text-sm font-medium cursor-pointer ml-2"
                    for="form_edit_type_instance"
                  >
                    This huddl only
                  </label>
                </div>
                <div>
                  <input
                    id="form_edit_type_all"
                    type="radio"
                    name="form[edit_type]"
                    class="w-4 h-4 accent-primary"
                    value="all"
                    checked={AshPhoenix.Form.value(@form.source, :edit_type) == "all"}
                  />
                  <label
                    class="text-sm font-medium cursor-pointer ml-2"
                    for="form_edit_type_all"
                  >
                    This and future huddlz in series
                  </label>
                </div>
              </div>

              <div class={"grid gap-4 sm:grid-cols-2 #{@form[:edit_type].value == "instance" && "hidden"}"}>
                <.input
                  field={@form[:frequency]}
                  type="select"
                  label="Frequency"
                  options={[
                    {"Weekly", "weekly"},
                    {"Monthly", "monthly"}
                  ]}
                  required
                />
                <.input field={@form[:repeat_until]} type="date" label="Repeat Until" required />
              </div>
            <% end %>
          </:recurring_section>

          <:actions>
            <div class="flex gap-4">
              <.button type="submit" phx-disable-with="Saving...">
                Save Huddl
              </.button>
              <.link
                navigate={~p"/groups/#{@group_slug}/huddlz/#{@huddl.id}"}
                class="px-6 py-2 text-sm font-medium border border-base-300 hover:border-primary/30 transition-colors"
              >
                Cancel
              </.link>
            </div>
          </:actions>
        </.huddl_form_fields>
      </.form>
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
  def handle_event("remove_current_image", _params, socket) do
    huddl = socket.assigns.huddl

    case Communities.get_current_huddl_image(huddl.id) do
      {:ok, image} when not is_nil(image) ->
        Communities.soft_delete_huddl_image(image, actor: socket.assigns.current_user)

        {:ok, updated_huddl} =
          get_huddl(huddl.id, socket.assigns.group_slug, socket.assigns.current_user)

        {:noreply, assign(socket, :huddl, updated_huddl)}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    socket =
      socket
      |> update_event_type_visibility(params)
      |> update_calculated_end_time(params)

    # Address autocomplete
    location_text = Map.get(params, "physical_location", "")

    socket =
      if socket.assigns.show_physical_location do
        maybe_autocomplete_address(socket, location_text)
      else
        socket
      end

    form = AshPhoenix.Form.validate(socket.assigns.form, params)
    {:noreply, assign(socket, :form, to_form(form))}
  end

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

    case AshPhoenix.Form.submit(socket.assigns.form,
           params: params,
           actor: socket.assigns.current_user
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

        with {:ok, image} <- Ash.get(HuddlImage, image_id) do
          Communities.assign_huddl_image_to_huddl(image, huddl.id,
            actor: socket.assigns.current_user
          )
        end
    end
  end

  defp get_huddl(id, group_slug, user) do
    case Huddl
         |> Ash.Query.filter(id == ^id)
         |> Ash.Query.load([
           :creator,
           :huddl_template,
           :status,
           :visible_virtual_link,
           :current_image_url,
           group: [:current_image_url]
         ])
         |> Ash.read_one(actor: user) do
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
end
