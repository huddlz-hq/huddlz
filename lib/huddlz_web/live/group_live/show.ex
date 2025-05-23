defmodule HuddlzWeb.GroupLive.Show do
  use HuddlzWeb, :live_view

  alias Huddlz.Communities.Group
  alias HuddlzWeb.Layouts

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_optional}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    with {:ok, group} <- get_group(id),
         :ok <- check_group_access(group, socket.assigns.current_user) do
      {:noreply,
       socket
       |> assign(:page_title, group.name)
       |> assign(:group, group)
       |> assign(:is_member, member?(group, socket.assigns.current_user))
       |> assign(:is_owner, owner?(group, socket.assigns.current_user))}
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
        <:actions></:actions>
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
            <h3>Members</h3>
            <p class="text-gray-600">Membership features coming soon!</p>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp get_group(id) do
    case Ash.get(Group, id, load: [:owner], authorize?: false) do
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
    require Ash.Query

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
end
