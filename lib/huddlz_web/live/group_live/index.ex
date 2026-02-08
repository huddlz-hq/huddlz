defmodule HuddlzWeb.GroupLive.Index do
  @moduledoc """
  LiveView for listing and searching groups.
  """
  use HuddlzWeb, :live_view

  alias Huddlz.Communities.Group
  alias Huddlz.Storage.GroupImages
  alias HuddlzWeb.Layouts
  require Ash.Query

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_optional}

  @impl true
  def mount(_params, _session, socket) do
    groups = list_groups()

    {:ok,
     socket
     |> assign(:groups, groups)
     |> assign(:can_create_group, Ash.can?({Group, :create_group}, socket.assigns.current_user))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Groups")
    |> assign(:group, nil)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.header>
        Groups
        <:actions :if={@can_create_group}>
          <.link navigate={~p"/groups/new"}>
            <.button>New Group</.button>
          </.link>
        </:actions>
      </.header>

      <div class="mt-8">
        <%= if @groups == [] do %>
          <div class="border border-dashed border-base-300 p-12 text-center">
            <p class="text-lg text-base-content/40">No groups found.</p>
            <%= if @can_create_group do %>
              <p class="mt-4">
                <.link navigate={~p"/groups/new"} class="text-primary hover:underline font-medium">
                  Create the first group
                </.link>
              </p>
            <% end %>
          </div>
        <% else %>
          <div class="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
            <%= for group <- @groups do %>
              <.link
                navigate={~p"/groups/#{group.slug}"}
                class="border border-base-300 overflow-hidden hover:border-primary/30 transition-colors group"
              >
                <div class="aspect-video overflow-hidden">
                  <%= if group.current_image_url do %>
                    <img
                      src={GroupImages.url(group.current_image_url)}
                      alt={group.name}
                      class="w-full h-full object-cover"
                    />
                  <% else %>
                    <div class="w-full h-full bg-base-100 flex items-center justify-center">
                      <span class="text-2xl font-bold text-base-content/30 text-center px-4 line-clamp-2">
                        {group.name}
                      </span>
                    </div>
                  <% end %>
                </div>
                <div class="p-4">
                  <h2 class="font-semibold">{group.name}</h2>
                  <p class="text-sm text-base-content/40 line-clamp-2">
                    {group.description || "No description provided."}
                  </p>
                  <p :if={group.location} class="text-xs text-base-content/50 mt-1">
                    <.icon name="hero-map-pin" class="h-3 w-3 inline" /> {group.location}
                  </p>
                </div>
              </.link>
            <% end %>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp list_groups do
    # For now, show all public groups
    # Later we can add filtering based on user's memberships
    Group
    |> Ash.Query.filter(is_public: true)
    |> Ash.Query.load(:current_image_url)
    |> Ash.read!()
  rescue
    _ -> []
  end
end
