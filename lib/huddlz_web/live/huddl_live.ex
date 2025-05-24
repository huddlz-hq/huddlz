defmodule HuddlzWeb.HuddlLive do
  use HuddlzWeb, :live_view

  alias Huddlz.Communities
  alias HuddlzWeb.Layouts

  # Authentication is optional - show cards to all but require auth for joining
  on_mount {HuddlzWeb.LiveUserAuth, :live_user_optional}

  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Only get huddls when socket is connected to minimize load
      upcoming_huddls =
        Communities.get_upcoming!(actor: socket.assigns[:current_user])
        |> Ash.load!([:status, :visible_virtual_link, :group])

      {:ok, assign(socket, huddls: upcoming_huddls, search_query: nil)}
    else
      # Initial load - empty to speed up first render
      {:ok, assign(socket, huddls: [], search_query: nil)}
    end
  end

  def handle_event("search", %{"query" => query}, socket) do
    huddls =
      if query && query != "" do
        Communities.search_huddlz!(query, actor: socket.assigns[:current_user])
        |> Ash.load!([:status, :visible_virtual_link, :group])
      else
        Communities.get_upcoming!(actor: socket.assigns[:current_user])
        |> Ash.load!([:status, :visible_virtual_link, :group])
      end

    {:noreply, assign(socket, huddls: huddls, search_query: query)}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="container mx-auto px-4 py-8">
        <div class="mb-8">
          <h1 class="text-3xl font-bold mb-4">Find your huddl</h1>
          <p class="text-lg text-base-content/80">
            Find and join engaging discussion events with interesting people
          </p>
          <form phx-change="search" phx-submit="search" class="mt-4">
            <div class="flex">
              <input
                type="text"
                name="query"
                value={@search_query}
                placeholder="Search huddlz..."
                class="flex-grow px-4 py-2 border rounded-l focus:outline-none bg-base-100 text-base-content"
              />
              <button type="submit" class="btn btn-primary px-4 py-2 rounded-r">
                Search
              </button>
            </div>
          </form>
        </div>

        <div class="w-full">
          <%= if Enum.empty?(@huddls) do %>
            <div class="text-center py-12">
              <p class="text-lg text-base-content/70">No huddlz found. Check back soon!</p>
            </div>
          <% else %>
            <div class="space-y-4">
              <%= for huddl <- @huddls do %>
                <.huddl_card huddl={huddl} show_group={true} />
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
