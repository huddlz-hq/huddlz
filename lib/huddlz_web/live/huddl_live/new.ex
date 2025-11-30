defmodule HuddlzWeb.HuddlLive.New do
  @moduledoc """
  LiveView for creating a new huddl within a group.
  """
  use HuddlzWeb, :live_view

  alias Huddlz.Communities
  alias Huddlz.Communities.Huddl
  alias Huddlz.Communities.HuddlImage
  alias Huddlz.Storage.HuddlImages
  alias HuddlzWeb.Layouts

  require Ash.Query

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(%{"group_slug" => group_slug}, _session, socket) do
    user = socket.assigns.current_user

    with {:ok, group} <- get_group_by_slug(group_slug, user),
         :ok <- authorize({Huddl, :create, %{group_id: group.id}}, user) do
      socket =
        socket
        |> assign_create_form(group, user)
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

      {:ok, socket}
    else
      {:error, :not_found} ->
        {:ok,
         handle_error(socket, :not_found, resource_name: "Group", fallback_path: ~p"/groups")}

      {:error, :not_authorized} ->
        {:ok,
         handle_error(socket, :not_authorized,
           message: "You don't have permission to create huddlz for this group",
           resource_path: ~p"/groups/#{group_slug}"
         )}
    end
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
          "creator_id" => user.id,
          "date" => Date.to_iso8601(tomorrow),
          "start_time" => Time.to_iso8601(default_time) |> String.slice(0..4),
          "duration_minutes" => "60"
        }
      )

    socket
    |> assign(:page_title, "Create New Huddl")
    |> assign(:group, group)
    |> assign(:form, to_form(form))
    |> assign(:show_virtual_link, false)
    |> assign(:show_physical_location, true)
    |> assign(:calculated_end_time, calculate_end_time(tomorrow, default_time, 60))
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
          socket.assigns.group.id
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
        navigate={~p"/groups/#{@group.slug}"}
        class="text-sm font-semibold leading-6 hover:underline"
      >
        <.icon name="hero-arrow-left" class="h-3 w-3" /> Back to {@group.name}
      </.link>

      <.header>
        Create New Huddl
        <:subtitle>
          Creating an event for <span class="font-semibold">{@group.name}</span>
        </:subtitle>
      </.header>

      <.form for={@form} id="huddl-form" phx-change="validate" phx-submit="save" class="space-y-6">
        <.input field={@form[:title]} type="text" label="Title" required />
        <.input field={@form[:description]} type="textarea" label="Description" rows="4" />

        <div>
          <label class="block text-sm font-medium mb-2">Huddl Image</label>
          <p class="text-base-content/70 text-sm mb-3">
            Upload a banner image for this huddl. If none is provided, the group image will be used.
          </p>

          <div
            class="border-2 border-dashed border-base-300 rounded-lg p-4 text-center hover:border-primary transition-colors"
            phx-drop-target={@uploads.huddl_image.ref}
          >
            <.live_file_input upload={@uploads.huddl_image} class="hidden" />
            <label for={@uploads.huddl_image.ref} class="cursor-pointer flex flex-col items-center">
              <.icon name="hero-photo" class="w-8 h-8 text-base-content/50 mb-2" />
              <span class="text-sm text-base-content/70">
                Click to upload or drag and drop
              </span>
              <span class="text-xs text-base-content/50 mt-1">
                JPG, PNG, or WebP (max 5MB)
              </span>
            </label>
          </div>

          <%= if @image_error do %>
            <p class="text-error text-sm mt-2">{@image_error}</p>
          <% end %>

          <%= if @pending_preview_url do %>
            <div class="mt-3 flex items-center gap-3 p-3 bg-base-200 rounded-lg">
              <img src={@pending_preview_url} class="w-20 h-12 rounded object-cover" alt="Preview" />
              <div class="flex-1 min-w-0">
                <p class="text-sm font-medium text-success flex items-center gap-1">
                  <.icon name="hero-check-circle" class="w-4 h-4" /> Image uploaded
                </p>
              </div>
              <button
                type="button"
                phx-click="cancel_pending_image"
                class="btn btn-ghost btn-sm btn-circle"
              >
                <.icon name="hero-x-mark" class="w-4 h-4" />
              </button>
            </div>
          <% else %>
            <%= for entry <- @uploads.huddl_image.entries do %>
              <div class="mt-3 flex items-center gap-3 p-3 bg-base-200 rounded-lg">
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
                  class="btn btn-ghost btn-sm btn-circle"
                >
                  <.icon name="hero-x-mark" class="w-4 h-4" />
                </button>
              </div>

              <%= for err <- upload_errors(@uploads.huddl_image, entry) do %>
                <p class="text-error text-sm mt-1">{upload_error_to_string(err)}</p>
              <% end %>
            <% end %>
          <% end %>

          <%= for err <- upload_errors(@uploads.huddl_image) do %>
            <p class="text-error text-sm mt-2">{upload_error_to_string(err)}</p>
          <% end %>
        </div>

        <div class="grid gap-4 sm:grid-cols-2">
          <.date_picker field={@form[:date]} label="Date" />
          <.time_picker field={@form[:start_time]} label="Start Time" />
        </div>

        <.duration_picker field={@form[:duration_minutes]} label="Duration" />

        <%= if @calculated_end_time do %>
          <div class="alert alert-info">
            <.icon name="hero-clock" class="h-5 w-5" />
            <span>Ends at: {@calculated_end_time}</span>
          </div>
        <% end %>

        <.input field={@form[:is_recurring]} type="checkbox" label="Make this a recurring event" />

        <%= if @form[:is_recurring].value do %>
          <div class="grid gap-4 sm:grid-cols-2">
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

        <%= if @group.is_public do %>
          <.input
            field={@form[:is_private]}
            type="checkbox"
            label="Make this a private event (only visible to group members)"
          />
        <% else %>
          <p class="text-sm text-base-content/80">
            <.icon name="hero-lock-closed" class="h-4 w-4 inline" />
            This will be a private event (private groups can only create private events)
          </p>
        <% end %>

        <div class="flex gap-4">
          <.button type="submit" phx-disable-with="Creating...">
            Create Huddl
          </.button>
          <.link navigate={~p"/groups/#{@group.slug}"} class="btn btn-ghost">
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
  def handle_event("validate", %{"form" => params}, socket) do
    event_type = Map.get(params, "event_type", "in_person")

    # Update visibility based on event type
    socket =
      socket
      |> assign(:show_physical_location, event_type in ["in_person", "hybrid"])
      |> assign(:show_virtual_link, event_type in ["virtual", "hybrid"])

    # Calculate end time if we have date, time, and duration
    socket =
      case {params["date"], params["start_time"], params["duration_minutes"]} do
        {date_str, time_str, duration_str}
        when date_str != "" and time_str != "" and duration_str != "" ->
          with {:ok, date} <- Date.from_iso8601(date_str),
               {:ok, time} <- parse_time(time_str),
               {duration, ""} <- Integer.parse(duration_str) do
            assign(socket, :calculated_end_time, calculate_end_time(date, time, duration))
          else
            _ -> socket
          end

        _ ->
          socket
      end

    form = AshPhoenix.Form.validate(socket.assigns.form, params)

    {:noreply, assign(socket, :form, to_form(form))}
  end

  def handle_event("save", %{"form" => params}, socket) do
    # Set is_private to true for private groups
    params =
      if socket.assigns.group.is_public do
        params
      else
        Map.put(params, "is_private", "true")
      end

    # Add group_id and creator_id to params
    params =
      params
      |> Map.put("group_id", socket.assigns.group.id)
      |> Map.put("creator_id", socket.assigns.current_user.id)

    case AshPhoenix.Form.submit(socket.assigns.form,
           params: params,
           actor: socket.assigns.current_user
         ) do
      {:ok, huddl} ->
        # Assign pending image to the new huddl if one was uploaded
        assign_pending_image_to_huddl(socket, huddl)

        {:noreply,
         socket
         |> put_flash(:info, "Huddl created successfully!")
         |> redirect(to: ~p"/groups/#{socket.assigns.group.slug}")}

      {:error, form} ->
        {:noreply, assign(socket, :form, to_form(form))}
    end
  end

  defp assign_pending_image_to_huddl(socket, huddl) do
    case socket.assigns[:pending_image_id] do
      nil ->
        :ok

      image_id ->
        with {:ok, image} <- Ash.get(HuddlImage, image_id) do
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

  defp calculate_end_time(date, time, duration_minutes) do
    case DateTime.new(date, time, "Etc/UTC") do
      {:ok, starts_at} ->
        ends_at = DateTime.add(starts_at, duration_minutes, :minute)

        # Format the end time nicely
        if Date.compare(DateTime.to_date(ends_at), date) == :eq do
          # Same day
          Calendar.strftime(ends_at, "%I:%M %p")
        else
          # Next day
          Calendar.strftime(ends_at, "%I:%M %p (next day)")
        end

      _ ->
        nil
    end
  end

  defp parse_time(time_str) do
    # Parse time string in format HH:MM or HH:MM:SS
    case String.split(time_str, ":") do
      [hour_str, minute_str] ->
        with {hour, ""} <- Integer.parse(hour_str),
             {minute, ""} <- Integer.parse(minute_str) do
          Time.new(hour, minute, 0)
        end

      [hour_str, minute_str, _second_str] ->
        with {hour, ""} <- Integer.parse(hour_str),
             {minute, ""} <- Integer.parse(minute_str) do
          Time.new(hour, minute, 0)
        end

      _ ->
        :error
    end
  end
end
