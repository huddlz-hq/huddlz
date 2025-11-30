defmodule HuddlzWeb.GroupLive.New do
  @moduledoc """
  LiveView for creating a new group.
  """
  use HuddlzWeb, :live_view

  alias Huddlz.Communities.Group
  alias Huddlz.Storage.GroupImages
  alias HuddlzWeb.Layouts

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    # Check if user can create groups
    if Ash.can?({Group, :create_group}, socket.assigns.current_user) do
      # Create a new changeset for the form
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
       |> allow_upload(:group_image,
         accept: ~w(.jpg .jpeg .png .webp),
         max_entries: 1,
         max_file_size: 5_000_000
       )}
    else
      {:ok,
       socket
       |> put_flash(:error, "You need to be logged in to create groups")
       |> redirect(to: ~p"/groups")}
    end
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    form =
      socket.assigns.form.source
      |> AshPhoenix.Form.validate(params)

    {:noreply,
     socket
     |> assign(:form, to_form(form))
     |> assign(:image_error, nil)}
  end

  @impl true
  def handle_event("cancel_image_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :group_image, ref)}
  end

  @impl true
  def handle_event("save", params, socket) do
    # Extract form params, handling both wrapped and unwrapped formats
    form_params = Map.get(params, "form", params)

    # Add the current user as the owner
    params_with_owner = Map.put(form_params, "owner_id", socket.assigns.current_user.id)

    case socket.assigns.form.source
         |> AshPhoenix.Form.validate(params_with_owner)
         |> AshPhoenix.Form.submit(params: params_with_owner, actor: socket.assigns.current_user) do
      {:ok, group} ->
        # Handle image upload after group creation
        socket = process_group_image_upload(socket, group)

        {:noreply,
         socket
         |> put_flash(:info, "Group created successfully")
         |> redirect(to: ~p"/groups/#{group.slug}")}

      {:error, form} ->
        {:noreply, assign(socket, :form, to_form(form))}
    end
  end

  defp process_group_image_upload(socket, group) do
    case uploaded_entries(socket, :group_image) do
      {[_ | _], []} ->
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

  defp upload_error_to_string(:too_large), do: "File is too large (max 5MB)"

  defp upload_error_to_string(:not_accepted),
    do: "Invalid file type. Please use JPG, PNG, or WebP"

  defp upload_error_to_string(:too_many_files), do: "Only one file can be uploaded at a time"
  defp upload_error_to_string(err), do: "Upload error: #{inspect(err)}"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.header>
        Create a New Group
        <:subtitle>Create a group to organize huddlz and connect with others</:subtitle>
      </.header>

      <form id="group-form" phx-change="validate" phx-submit="save" class="space-y-6">
        <.input field={@form[:name]} type="text" label="Group Name" required />

        <div class="rounded-md bg-base-200 p-4">
          <p class="text-sm text-base-content/80">
            Your group will be available at:
          </p>
          <p class="font-mono text-sm mt-1 break-all">
            {url(~p"/groups/#{@form[:slug].value || "..."}")}
          </p>
        </div>

        <.input field={@form[:description]} type="textarea" label="Description" />
        <.input field={@form[:location]} type="text" label="Location" />

        <div>
          <label class="block text-sm font-medium mb-2">Group Image</label>
          <p class="text-base-content/70 text-sm mb-3">
            Upload a banner image for your group (16:9 ratio recommended).
          </p>

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
          <.button type="submit" phx-disable-with="Creating...">Create Group</.button>
          <.link navigate={~p"/groups"} class="btn btn-ghost">Cancel</.link>
        </div>
      </form>
    </Layouts.app>
    """
  end
end
