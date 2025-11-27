defmodule HuddlzWeb.GroupLive.Edit do
  use HuddlzWeb, :live_view

  alias HuddlzWeb.Layouts

  require Ash.Query

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    with {:ok, group} <- get_group_by_slug(slug, socket.assigns.current_user),
         :ok <- check_can_edit_group(group, socket.assigns.current_user) do
      form =
        AshPhoenix.Form.for_update(group, :update_details,
          actor: socket.assigns.current_user,
          forms: [auto?: true]
        )
        |> to_form()

      {:ok,
       socket
       |> assign(:page_title, "Edit Group")
       |> assign(:group, group)
       |> assign(:form, form)
       |> assign(:original_slug, group.slug)
       |> assign(:slug_changed, false)}
    else
      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Group not found")
         |> redirect(to: ~p"/groups")}

      {:error, :not_authorized} ->
        {:ok,
         socket
         |> put_flash(:error, "You don't have permission to edit this group")
         |> redirect(to: ~p"/groups/#{slug}")}
    end
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
        <.input field={@form[:image_url]} type="text" label="Image URL" />

        <div>
          <label class="block text-sm font-medium mb-2">Privacy</label>
          <.input field={@form[:is_public]} type="checkbox" label="Public group (visible to everyone)" />
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
     |> assign(:slug_changed, slug_changed)}
  end

  def handle_event("update_group", %{"form" => params}, socket) do
    case socket.assigns.group
         |> Ash.Changeset.for_update(:update_details, params, actor: socket.assigns.current_user)
         |> Ash.update() do
      {:ok, updated_group} ->
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

  defp get_group_by_slug(slug, actor) do
    case Huddlz.Communities.get_by_slug(slug, actor: actor, load: [:owner]) do
      {:ok, nil} -> {:error, :not_found}
      {:ok, group} -> {:ok, group}
      {:error, _} -> {:error, :not_found}
    end
  end

  defp check_can_edit_group(group, user) do
    if group.owner_id == user.id do
      :ok
    else
      {:error, :not_authorized}
    end
  end
end
