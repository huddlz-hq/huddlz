defmodule HuddlzWeb.GroupLive.Edit do
  @moduledoc """
  LiveView for editing an existing group's details.
  """
  use HuddlzWeb, :live_view

  alias Huddlz.Storage.GroupImages
  alias HuddlzWeb.Layouts

  require Ash.Query

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    user = socket.assigns.current_user

    with {:ok, group} <- get_group_by_slug(slug, user),
         :ok <- authorize({group, :update_details}, user) do
      {:ok, assign_edit_form(socket, group)}
    else
      {:error, :not_found} ->
        {:ok,
         handle_error(socket, :not_found, resource_name: "Group", fallback_path: ~p"/groups")}

      {:error, :not_authorized} ->
        {:ok,
         handle_error(socket, :not_authorized,
           resource_name: "group",
           action: "edit",
           resource_path: ~p"/groups/#{slug}"
         )}
    end
  end

  defp assign_edit_form(socket, group) do
    form =
      AshPhoenix.Form.for_update(group, :update_details,
        actor: socket.assigns.current_user,
        forms: [auto?: true]
      )
      |> to_form()

    socket
    |> assign(:page_title, "Edit Group")
    |> assign(:group, group)
    |> assign(:form, form)
    |> assign(:original_slug, group.slug)
    |> assign(:slug_changed, false)
    |> assign(:image_error, nil)
    |> allow_upload(:group_image,
      accept: ~w(.jpg .jpeg .png .webp),
      max_entries: 1,
      max_file_size: 5_000_000
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.link
        navigate={~p"/groups/#{@original_slug}"}
        class="text-sm font-semibold leading-6 hover:underline"
      >
        <.icon name="hero-arrow-left" class="h-3 w-3" /> Back to {@group.name}
      </.link>

      <.header>
        Edit Group
        <:subtitle>Update your group details</:subtitle>
      </.header>

      <form
        id="edit-group-form"
        phx-submit="update_group"
        phx-change="validate"
        class="space-y-6 mt-6"
      >
        <.input field={@form[:name]} type="text" label="Group Name" required />

        <div>
          <.input
            field={@form[:slug]}
            type="text"
            label="URL Slug"
            pattern="[a-z0-9-]+"
            title="Only lowercase letters, numbers, and hyphens allowed"
            required
          />
          <p class="text-sm text-base-content/80 mt-1">
            Your group is available at:
          </p>
          <p class="font-mono text-sm mt-1 break-all">
            {url(~p"/groups/#{@form[:slug].value || "..."}")}
          </p>

          <%= if @slug_changed do %>
            <div class="rounded-md bg-yellow-50 p-4 mt-2">
              <div class="flex">
                <div class="flex-shrink-0">
                  <.icon name="hero-exclamation-triangle" class="h-5 w-5 text-yellow-400" />
                </div>
                <div class="ml-3">
                  <h3 class="text-sm font-medium text-yellow-800">
                    Warning: URL Change
                  </h3>
                  <div class="mt-2 text-sm text-yellow-700">
                    <p>Changing the slug will break existing links to this group.</p>
                    <p class="mt-1 break-all">
                      Old URL: <span class="font-mono">{url(~p"/groups/#{@original_slug}")}</span>
                    </p>
                    <p class="break-all">
                      New URL: <span class="font-mono">{url(~p"/groups/#{@form[:slug].value}")}</span>
                    </p>
                  </div>
                </div>
              </div>
            </div>
          <% end %>
        </div>

        <.input field={@form[:description]} type="textarea" label="Description" rows="4" />
        <.input field={@form[:location]} type="text" label="Location" />

        <div>
          <label class="block text-sm font-medium mb-2">Group Image</label>
          <p class="text-base-content/70 text-sm mb-3">
            Upload a banner image for your group (16:9 ratio recommended).
          </p>

          <%= if @group.current_image_url && @uploads.group_image.entries == [] do %>
            <div class="mb-4">
              <div class="relative inline-block">
                <img
                  src={GroupImages.url(@group.current_image_url)}
                  alt={@group.name}
                  class="rounded-lg max-w-md aspect-video object-cover"
                />
                <button
                  type="button"
                  phx-click="remove_image"
                  class="absolute top-2 right-2 btn btn-circle btn-sm btn-error"
                  data-confirm="Are you sure you want to remove this image?"
                >
                  <.icon name="hero-trash" class="w-4 h-4" />
                </button>
              </div>
              <p class="text-sm text-base-content/70 mt-2">
                Current image. Upload a new one to replace it.
              </p>
            </div>
          <% end %>

          <div
            class="border-2 border-dashed border-base-300 rounded-lg p-4 text-center hover:border-primary transition-colors"
            phx-drop-target={@uploads.group_image.ref}
          >
            <.live_file_input upload={@uploads.group_image} class="hidden" />
            <label for={@uploads.group_image.ref} class="cursor-pointer flex flex-col items-center">
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

          <%= for entry <- @uploads.group_image.entries do %>
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

            <%= for err <- upload_errors(@uploads.group_image, entry) do %>
              <p class="text-error text-sm mt-1">{upload_error_to_string(err)}</p>
            <% end %>
          <% end %>

          <%= for err <- upload_errors(@uploads.group_image) do %>
            <p class="text-error text-sm mt-2">{upload_error_to_string(err)}</p>
          <% end %>
        </div>

        <div>
          <label class="block text-sm font-medium mb-2">Privacy</label>
          <.input
            field={@form[:is_public]}
            type="checkbox"
            label="Public group (visible to everyone)"
          />
          <p class="text-sm text-base-content/70">
            Public groups are visible to all users. Private groups are only visible to members.
          </p>
        </div>

        <div class="flex gap-4">
          <.button type="submit" phx-disable-with="Saving...">
            Save Changes
          </.button>
          <.link navigate={~p"/groups/#{@original_slug}"} class="btn btn-ghost">
            Cancel
          </.link>
        </div>
      </form>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    form =
      socket.assigns.form.source
      |> AshPhoenix.Form.validate(params)
      |> to_form()

    slug_changed = params["slug"] != socket.assigns.original_slug

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:slug_changed, slug_changed)
     |> assign(:image_error, nil)}
  end

  @impl true
  def handle_event("cancel_image_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :group_image, ref)}
  end

  @impl true
  def handle_event("remove_image", _params, socket) do
    group = socket.assigns.group
    user = socket.assigns.current_user

    # Soft-delete all images for the group
    case soft_delete_all_group_images(group, user) do
      :ok ->
        # Reload group to clear the image
        {:ok, updated_group} =
          Ash.load(group, [:current_image_url], actor: user)

        {:noreply,
         socket
         |> put_flash(:info, "Image removed")
         |> assign(:group, updated_group)}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to remove image")}
    end
  end

  def handle_event("update_group", %{"form" => params}, socket) do
    case socket.assigns.group
         |> Ash.Changeset.for_update(:update_details, params, actor: socket.assigns.current_user)
         |> Ash.update() do
      {:ok, updated_group} ->
        # Handle image upload if present
        socket = process_group_image_upload(socket, updated_group)

        {:noreply,
         socket
         |> put_flash(:info, "Group updated successfully")
         |> redirect(to: ~p"/groups/#{updated_group.slug}")}

      {:error, changeset} ->
        form =
          AshPhoenix.Form.for_update(socket.assigns.group, :update_details,
            errors: changeset.errors,
            actor: socket.assigns.current_user,
            forms: [auto?: true]
          )
          |> to_form()

        {:noreply, assign(socket, :form, form)}
    end
  end

  defp process_group_image_upload(socket, group) do
    case uploaded_entries(socket, :group_image) do
      {[_ | _], []} ->
        # Soft-delete existing images before creating new
        soft_delete_all_group_images(group, socket.assigns.current_user)

        consume_uploaded_entries(socket, :group_image, fn %{path: path}, entry ->
          store_group_image(path, entry, group.id, socket.assigns.current_user)
        end)

        socket

      {[], _} ->
        socket
    end
  end

  defp store_group_image(path, entry, group_id, user) do
    case GroupImages.store(path, entry.client_name, entry.client_type, group_id) do
      {:ok, %{storage_path: storage_path, thumbnail_path: thumbnail_path, size_bytes: size_bytes}} ->
        Huddlz.Communities.create_group_image(
          %{
            filename: entry.client_name,
            content_type: entry.client_type,
            size_bytes: size_bytes,
            storage_path: storage_path,
            thumbnail_path: thumbnail_path,
            group_id: group_id
          },
          actor: user
        )

        {:ok, :success}

      {:error, reason} ->
        {:ok, {:error, reason}}
    end
  end

  defp soft_delete_all_group_images(group, user) do
    case Huddlz.Communities.list_group_images(group.id, actor: user) do
      {:ok, images} ->
        Enum.each(images, fn image ->
          Huddlz.Communities.soft_delete_group_image(image, actor: user)
        end)

        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_group_by_slug(slug, actor) do
    case Huddlz.Communities.get_by_slug(slug,
           actor: actor,
           load: [:owner, :current_image_url]
         ) do
      {:ok, nil} -> {:error, :not_found}
      {:ok, group} -> {:ok, group}
      {:error, _} -> {:error, :not_found}
    end
  end

  defp upload_error_to_string(:too_large), do: "File is too large (max 5MB)"

  defp upload_error_to_string(:not_accepted),
    do: "Invalid file type. Please use JPG, PNG, or WebP"

  defp upload_error_to_string(:too_many_files), do: "Only one file can be uploaded at a time"
  defp upload_error_to_string(err), do: "Upload error: #{inspect(err)}"
end
