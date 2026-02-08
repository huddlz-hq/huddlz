defmodule HuddlzWeb.HuddlLive.Edit do
  @moduledoc """
  LiveView for editing an existing huddl's details.
  """
  use HuddlzWeb, :live_view

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
    form =
      AshPhoenix.Form.for_update(huddl, :update,
        domain: Huddlz.Communities,
        actor: user,
        forms: [auto?: true]
      )

    form = maybe_add_recurring_fields(form, huddl)

    socket
    |> assign(:page_title, huddl.title)
    |> assign(:group_slug, group_slug)
    |> assign(:huddl, huddl)
    |> assign(:show_physical_location, !!huddl.physical_location)
    |> assign(:show_virtual_link, !!huddl.virtual_link)
    |> assign(:form, to_form(form))
  end

  defp maybe_add_recurring_fields(form, huddl) do
    if huddl.huddl_template_id do
      AshPhoenix.Form.validate(form, %{
        is_recurring: true,
        repeat_until: huddl.huddl_template.repeat_until,
        frequency: huddl.huddl_template.frequency
      })
    else
      form
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
    # Clean up previous pending image if user re-uploads
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
        # Soft-delete previous pending image (will be cleaned up by Oban job)
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
        <.input field={@form[:title]} type="text" label="Title" required />
        <.input field={@form[:description]} type="textarea" label="Description" rows="4" />

        <div>
          <label class="mono-label text-primary/70 mb-2 block">
            Huddl Image
          </label>

          <%= cond do %>
            <% @pending_preview_url -> %>
              <div class="mb-3 flex items-center gap-3 p-3 bg-base-200">
                <img src={@pending_preview_url} class="w-20 h-12 rounded object-cover" alt="Preview" />
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
                  class="w-20 h-12 rounded object-cover"
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
                  class="w-20 h-12 rounded object-cover opacity-70"
                  alt="Group image"
                />
                <div class="flex-1 min-w-0">
                  <p class="text-sm text-base-content/50">(Using group image)</p>
                </div>
              </div>
            <% true -> %>
              <div class="mb-3 flex items-center gap-3 p-3 bg-base-200/50 border border-dashed border-base-300">
                <div class="w-20 h-12 rounded bg-base-100 flex items-center justify-center">
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
            <label for={@uploads.huddl_image.ref} class="cursor-pointer flex flex-col items-center">
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
              <.live_img_preview entry={entry} class="w-20 h-12 rounded object-cover" />
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

        <div class="grid gap-4 sm:grid-cols-2">
          <.input field={@form[:starts_at]} type="datetime-local" label="Start Date & Time" required />
          <.input field={@form[:ends_at]} type="datetime-local" label="End Date & Time" required />
        </div>

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
              <label class="text-sm font-medium cursor-pointer ml-2" for="form_edit_type_instance">
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
              <label class="text-sm font-medium cursor-pointer ml-2" for="form_edit_type_all">
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

        <.input
          field={@form[:event_type]}
          type="select"
          label="Event Type"
          options={[
            {"In-Person", "in_person"},
            {"Virtual", "virtual"},
            {"Hybrid (Both In-Person and Virtual)", "hybrid"}
          ]}
          required
          phx-change="event_type_changed"
        />

        <%= if @show_physical_location do %>
          <.input
            field={@form[:physical_location]}
            type="text"
            label="Physical Location"
            placeholder="e.g., 123 Main St, City, State"
          />
        <% end %>

        <%= if @show_virtual_link do %>
          <.input
            field={@form[:virtual_link]}
            type="text"
            label="Virtual Meeting Link"
            placeholder="e.g., https://zoom.us/j/123456789"
          />
        <% end %>

        <%= if @huddl.group.is_public do %>
          <.input
            field={@form[:is_private]}
            type="checkbox"
            label="Make this a private event (only visible to group members)"
          />
        <% else %>
          <p class="text-sm text-base-content/60">
            <.icon name="hero-lock-closed" class="h-4 w-4 inline" />
            This will be a private event (private groups can only create private events)
          </p>
        <% end %>

        <div class="flex gap-4">
          <.button type="submit" phx-disable-with="Creating...">
            Save Huddl
          </.button>
          <.link
            navigate={~p"/groups/#{@group_slug}/huddlz/#{@huddl.id}"}
            class="px-6 py-2 text-sm font-medium border border-base-300 hover:border-primary/30 transition-colors"
          >
            Cancel
          </.link>
        </div>
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
    # Soft-delete current image - will trigger Oban cleanup
    huddl = socket.assigns.huddl

    case Communities.get_current_huddl_image(huddl.id) do
      {:ok, image} when not is_nil(image) ->
        Communities.soft_delete_huddl_image(image, actor: socket.assigns.current_user)

        # Reload huddl to reflect image removal
        {:ok, updated_huddl} =
          get_huddl(huddl.id, socket.assigns.group_slug, socket.assigns.current_user)

        {:noreply, assign(socket, :huddl, updated_huddl)}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    event_type = Map.get(params, "event_type", "in_person")

    # Update visibility based on event type
    socket =
      socket
      |> assign(:show_physical_location, event_type in ["in_person", "hybrid"])
      |> assign(:show_virtual_link, event_type in ["virtual", "hybrid"])

    form =
      AshPhoenix.Form.validate(socket.assigns.form, params)

    {:noreply, assign(socket, :form, to_form(form))}
  end

  def handle_event("event_type_changed", %{"form" => params}, socket) do
    event_type = params["event_type"]

    # Update visibility based on event type
    socket =
      socket
      |> assign(:show_physical_location, event_type in ["in_person", "hybrid"])
      |> assign(:show_virtual_link, event_type in ["virtual", "hybrid"])

    form =
      AshPhoenix.Form.update_params(socket.assigns.form, &Map.merge(&1, params))

    {:noreply, assign(socket, :form, to_form(form))}
  end

  def handle_event("save", %{"form" => params}, socket) do
    # Set is_private to true for private groups
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
        # Assign pending image to the huddl if one was uploaded
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
        # Soft-delete existing image if present
        case Communities.get_current_huddl_image(huddl.id) do
          {:ok, existing} when not is_nil(existing) ->
            Communities.soft_delete_huddl_image(existing, actor: socket.assigns.current_user)

          _ ->
            :ok
        end

        # Assign new pending image
        with {:ok, image} <- Ash.get(HuddlImage, image_id) do
          Communities.assign_huddl_image_to_huddl(image, huddl.id,
            actor: socket.assigns.current_user
          )
        end
    end
  end

  defp get_huddl(id, group_slug, user) do
    # Get the huddl and verify it belongs to the group with the given slug
    # Authorization is handled by Ash policies via Ash.can? in handle_params
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
        # Verify the huddl belongs to the group in the URL
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
