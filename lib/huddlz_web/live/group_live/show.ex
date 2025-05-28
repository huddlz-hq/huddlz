defmodule HuddlzWeb.GroupLive.Show do
  use HuddlzWeb, :live_view

  alias Huddlz.Communities.Group
  alias Huddlz.Communities.GroupMember
  alias Huddlz.Communities.Huddl
  alias HuddlzWeb.Layouts

  require Ash.Query

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_optional}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:show_edit_modal, false)
     |> assign(:edit_form, nil)
     |> assign(:slug_changed, false)}
  end

  @impl true
  def handle_params(%{"slug" => slug}, _, socket) do
    with {:ok, group} <- get_group_by_slug(slug),
         :ok <- check_group_access(group, socket.assigns.current_user) do
      members = get_members(group, socket.assigns.current_user)

      huddlz = get_group_huddlz(group, socket.assigns.current_user)

      {:noreply,
       socket
       |> assign(:page_title, group.name)
       |> assign(:group, group)
       |> assign(:members, members)
       |> assign(:member_count, get_member_count(group))
       |> assign(:is_member, member?(group, socket.assigns.current_user))
       |> assign(:is_owner, owner?(group, socket.assigns.current_user))
       |> assign(:is_organizer, organizer?(group, socket.assigns.current_user))
       |> assign(:huddlz, huddlz)}
    else
      {:error, :not_found} ->
        {:noreply,
         socket
         |> put_flash(:error, "Group not found")
         |> redirect(to: ~p"/groups")}

      {:error, :not_authorized} ->
        {:noreply,
         socket
         |> put_flash(:error, "You don't have access to this private group")
         |> redirect(to: ~p"/groups")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.link navigate={~p"/groups"} class="text-sm font-semibold leading-6 hover:underline">
        <.icon name="hero-arrow-left" class="h-3 w-3" /> Back to groups
      </.link>

      <.header>
        {@group.name}
        <:subtitle>
          <%= if @group.is_public do %>
            <span class="badge badge-secondary">Public Group</span>
          <% else %>
            <span class="badge">Private Group</span>
          <% end %>
          <%= if @is_owner do %>
            <span class="badge badge-primary ml-2">Owner</span>
          <% end %>
        </:subtitle>
        <:actions>
          <%= if @current_user do %>
            <%= if @is_owner do %>
              <.button phx-click="open_edit_modal" class="btn btn-ghost">
                <.icon name="hero-pencil" class="h-4 w-4" /> Edit Group
              </.button>
            <% end %>

            <%= if @is_owner || @is_organizer do %>
              <.link navigate={~p"/groups/#{@group.slug}/huddlz/new"} class="btn btn-primary">
                <.icon name="hero-plus" class="h-4 w-4" /> Create Huddl
              </.link>
            <% end %>

            <%= if !@is_owner do %>
              <%= if @is_member do %>
                <.button
                  phx-click="leave_group"
                  data-confirm="Are you sure you want to leave this group?"
                >
                  Leave Group
                </.button>
              <% else %>
                <%= if @group.is_public do %>
                  <.button phx-click="join_group">
                    Join Group
                  </.button>
                <% end %>
              <% end %>
            <% end %>
          <% end %>
        </:actions>
      </.header>

      <div class="mt-8">
        <%= if @group.image_url do %>
          <div class="mb-6">
            <img
              src={@group.image_url}
              alt={@group.name}
              class="w-full max-w-2xl rounded-lg shadow-lg"
            />
          </div>
        <% end %>

        <div class="prose max-w-none">
          <div class="grid gap-6 md:grid-cols-2">
            <div>
              <h3>Description</h3>
              <p>{@group.description || "No description provided."}</p>
            </div>

            <%= if @group.location do %>
              <div>
                <h3>Location</h3>
                <p class="flex items-center gap-2">
                  <.icon name="hero-map-pin" class="h-5 w-5" />
                  {@group.location}
                </p>
              </div>
            <% end %>
          </div>

          <div class="mt-8">
            <h3>Group Details</h3>
            <dl class="grid gap-4 sm:grid-cols-2">
              <div>
                <dt class="font-medium text-gray-500">Created</dt>
                <dd>{format_date(@group.created_at)}</dd>
              </div>
              <div>
                <dt class="font-medium text-gray-500">Owner</dt>
                <dd>{@group.owner.display_name || @group.owner.email}</dd>
              </div>
            </dl>
          </div>

          <div class="mt-8">
            <h3>Upcoming Huddlz</h3>
            <%= if Enum.empty?(@huddlz) do %>
              <p class="text-gray-600 mt-4">No upcoming huddlz scheduled.</p>
            <% else %>
              <div class="mt-4 space-y-4">
                <%= for huddl <- @huddlz do %>
                  <.huddl_card huddl={huddl} />
                <% end %>
              </div>
            <% end %>
          </div>

          <div class="mt-8">
            <h3>Members ({@member_count})</h3>
            <%= if @members do %>
              <div class="mt-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
                <%= for member <- @members do %>
                  <div class="flex items-center gap-3 rounded-lg border p-3">
                    <div class="flex-1">
                      <p class="font-medium">
                        {member.display_name || "User"}
                        <%= if member.id == @group.owner_id do %>
                          <span class="text-xs font-normal text-gray-500">(Owner)</span>
                        <% end %>
                      </p>
                      <p class="text-sm text-gray-500">{member.email}</p>
                    </div>
                  </div>
                <% end %>
              </div>
            <% else %>
              <p class="text-gray-600">Members list is only visible to verified users.</p>
            <% end %>
          </div>
        </div>
      </div>

      <%= if @show_edit_modal do %>
        <div id="edit-group-modal" class="fixed inset-0 z-50 overflow-y-auto">
          <div class="flex min-h-screen items-center justify-center p-4">
            <div
              class="fixed inset-0 bg-black/50 transition-opacity"
              aria-hidden="true"
              phx-click="close_edit_modal"
            >
            </div>

            <div class="relative mx-auto w-full max-w-2xl rounded-lg bg-white p-6 shadow-xl">
              <.header>
                Edit Group
                <:subtitle>Update your group details</:subtitle>
              </.header>

              <form
                id="edit-group-form"
                phx-submit="update_group"
                phx-change="validate_edit"
                class="space-y-6 mt-6"
              >
                <.input field={@edit_form[:name]} type="text" label="Group Name" />
                <.input field={@edit_form[:slug]} type="text" label="URL Slug" />
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
                          <p class="mt-1">
                            Old URL: <span class="font-mono">/groups/{@group.slug}</span>
                          </p>
                          <p>
                            New URL: <span class="font-mono">/groups/{@edit_form[:slug].value}</span>
                          </p>
                        </div>
                      </div>
                    </div>
                  </div>
                <% end %>
                <.input field={@edit_form[:description]} type="textarea" label="Description" />
                <.input field={@edit_form[:location]} type="text" label="Location" />
                <.input field={@edit_form[:image_url]} type="text" label="Image URL" />

                <div>
                  <label class="block text-sm font-medium mb-2">Privacy</label>
                  <label class="flex items-center gap-3">
                    <input type="hidden" name={@edit_form[:is_public].name} value="false" />
                    <input
                      type="checkbox"
                      name={@edit_form[:is_public].name}
                      id={@edit_form[:is_public].id}
                      value="true"
                      checked={@edit_form[:is_public].value == true}
                      class="checkbox"
                    />
                    <span>Public group (visible to everyone)</span>
                  </label>
                </div>

                <div class="flex gap-4 mt-6">
                  <.button type="submit" phx-disable-with="Saving...">Save Changes</.button>
                  <.button type="button" phx-click="close_edit_modal" class="btn-ghost">
                    Cancel
                  </.button>
                </div>
              </form>
            </div>
          </div>
        </div>
      <% end %>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("join_group", _, socket) do
    case join_group(socket.assigns.group, socket.assigns.current_user) do
      {:ok, _} ->
        group = Ash.reload!(socket.assigns.group)
        members = get_members(group, socket.assigns.current_user)

        {:noreply,
         socket
         |> put_flash(:info, "Successfully joined the group!")
         |> assign(:is_member, true)
         |> assign(:members, members)
         |> assign(:member_count, get_member_count(group))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to join group")}
    end
  end

  def handle_event("leave_group", _, socket) do
    case leave_group(socket.assigns.group, socket.assigns.current_user) do
      {:ok, _} ->
        group = Ash.reload!(socket.assigns.group)
        members = get_members(group, socket.assigns.current_user)

        {:noreply,
         socket
         |> put_flash(:info, "Successfully left the group")
         |> assign(:is_member, false)
         |> assign(:members, members)
         |> assign(:member_count, get_member_count(group))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to leave group")}
    end
  end

  def handle_event("open_edit_modal", _, socket) do
    form =
      AshPhoenix.Form.for_update(socket.assigns.group, :update_details,
        actor: socket.assigns.current_user,
        forms: [auto?: true]
      )
      |> to_form()

    {:noreply,
     socket
     |> assign(:show_edit_modal, true)
     |> assign(:edit_form, form)
     |> assign(:slug_changed, false)}
  end

  def handle_event("close_edit_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:show_edit_modal, false)
     |> assign(:edit_form, nil)
     |> assign(:slug_changed, false)}
  end

  def handle_event("validate_edit", %{"form" => params}, socket) do
    form =
      socket.assigns.edit_form.source
      |> AshPhoenix.Form.validate(params)
      |> to_form()

    slug_changed = params["slug"] != socket.assigns.group.slug

    {:noreply,
     socket
     |> assign(:edit_form, form)
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
         |> assign(:group, updated_group)
         |> assign(:show_edit_modal, false)
         |> assign(:edit_form, nil)
         |> assign(:slug_changed, false)
         |> then(fn s ->
           if updated_group.slug != socket.assigns.group.slug do
             push_navigate(s, to: ~p"/groups/#{updated_group.slug}")
           else
             s
           end
         end)}

      {:error, changeset} ->
        form =
          AshPhoenix.Form.for_update(socket.assigns.group, :update_details,
            errors: changeset.errors,
            actor: socket.assigns.current_user,
            forms: [auto?: true]
          )
          |> to_form()

        {:noreply, assign(socket, :edit_form, form)}
    end
  end

  defp get_group_by_slug(slug) do
    case Group
         |> Ash.Query.for_read(:get_by_slug, %{slug: slug})
         |> Ash.Query.load(:owner)
         |> Ash.read_one(authorize?: false) do
      {:ok, nil} -> {:error, :not_found}
      {:ok, group} -> {:ok, group}
      {:error, _} -> {:error, :not_found}
    end
  end

  defp check_group_access(group, user) do
    cond do
      group.is_public -> :ok
      user == nil -> {:error, :not_authorized}
      owner?(group, user) -> :ok
      member?(group, user) -> :ok
      true -> {:error, :not_authorized}
    end
  end

  defp member?(_group, nil), do: false

  defp member?(group, user) do
    Huddlz.Communities.GroupMember
    |> Ash.Query.filter(group_id == ^group.id and user_id == ^user.id)
    |> Ash.exists?(authorize?: false)
  end

  defp owner?(_group, nil), do: false

  defp owner?(group, user) do
    group.owner_id == user.id
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%B %d, %Y")
  end

  defp get_members(group, current_user) do
    if can_see_members?(group, current_user) do
      load_members(group)
    else
      nil
    end
  end

  defp can_see_members?(group, current_user) do
    owner_or_organizer?(group, current_user) ||
      verified_member?(group, current_user) ||
      verified_non_member_of_public_group?(group, current_user)
  end

  defp owner_or_organizer?(group, current_user) do
    owner?(group, current_user) || organizer?(group, current_user)
  end

  defp verified_member?(group, current_user) do
    member?(group, current_user) && current_user && current_user.role == :verified
  end

  defp verified_non_member_of_public_group?(group, current_user) do
    group.is_public && current_user && current_user.role == :verified
  end

  defp load_members(group) do
    GroupMember
    |> Ash.Query.filter(group_id == ^group.id)
    |> Ash.Query.load(:user)
    |> Ash.read!(authorize?: false)
    |> Enum.map(& &1.user)
  end

  defp get_member_count(group) do
    GroupMember
    |> Ash.Query.filter(group_id == ^group.id)
    |> Ash.count!(authorize?: false)
  end

  defp organizer?(_group, nil), do: false

  defp organizer?(group, user) do
    GroupMember
    |> Ash.Query.filter(group_id == ^group.id and user_id == ^user.id and role == :organizer)
    |> Ash.exists?(authorize?: false)
  end

  defp join_group(group, user) do
    GroupMember
    |> Ash.Changeset.for_create(
      :join_group,
      %{
        group_id: group.id,
        user_id: user.id
      },
      actor: user
    )
    |> Ash.create()
  end

  defp leave_group(group, user) do
    GroupMember
    |> Ash.Query.filter(group_id == ^group.id and user_id == ^user.id)
    |> Ash.read_one!(authorize?: false)
    |> Ash.destroy(action: :leave_group, actor: user)
  end

  defp get_group_huddlz(group, user) do
    Huddl
    |> Ash.Query.filter(group_id == ^group.id)
    |> Ash.Query.filter(starts_at > ^DateTime.utc_now())
    |> Ash.Query.sort(starts_at: :asc)
    |> Ash.Query.load([:status, :visible_virtual_link, :group])
    |> Ash.read!(actor: user)
  end
end
