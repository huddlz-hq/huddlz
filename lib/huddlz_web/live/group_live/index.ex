defmodule HuddlzWeb.GroupLive.Index do
  @moduledoc """
  LiveView for listing and searching groups.
  """
  use HuddlzWeb, :live_view

  alias Huddlz.Communities.Group
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
          <div class="hero min-h-[200px] bg-base-200 rounded-box">
            <div class="hero-content text-center">
              <div>
                <p class="text-lg text-base-content/60">No groups found.</p>
                <%= if @can_create_group do %>
                  <p class="mt-4">
                    <.link navigate={~p"/groups/new"} class="link link-primary">
                      Create the first group
                    </.link>
                  </p>
                <% end %>
              </div>
            </div>
          </div>
        <% else %>
          <div class="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
            <%= for group <- @groups do %>
              <div class="card bg-base-100 shadow-xl">
                <figure>
                  <%= if group.image_url do %>
                    <img src={group.image_url} alt={group.name} class="h-48 w-full object-cover" />
                  <% else %>
                    <img
                      src={"https://placehold.co/600x400/orange/white?text=#{group.name}"}
                      alt={group.name}
                      class="h-48 w-full object-cover"
                    />
                  <% end %>
                </figure>
                <div class="card-body">
                  <h2 class="card-title">
                    {group.name}
                    <%= if group.is_public do %>
                      <div class="badge badge-secondary">Public</div>
                    <% else %>
                      <div class="badge badge-ghost">Private</div>
                    <% end %>
                  </h2>
                  <p class="text-base-content/70">
                    {group.description || "No description provided."}
                  </p>
                  <p :if={group.location} class="text-sm text-base-content/60">
                    <.icon name="hero-map-pin" class="h-4 w-4 inline" /> {group.location}
                  </p>
                  <div class="card-actions justify-end">
                    <.link navigate={~p"/groups/#{group.slug}"}>
                      <.button class="btn-sm">View Group</.button>
                    </.link>
                  </div>
                </div>
              </div>
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
    |> Ash.read!()
  rescue
    _ -> []
  end
end
