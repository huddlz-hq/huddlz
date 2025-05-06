defmodule HuddlzWeb.SoireeLive do
  use HuddlzWeb, :live_view

  alias Huddlz.Soirees
  alias HuddlzWeb.Layouts

  # Authentication is optional - show cards to all but require auth for joining
  on_mount {HuddlzWeb.LiveUserAuth, :live_user_optional}

  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Only get soirees when socket is connected to minimize load
      upcoming_soirees = Soirees.get_upcoming!()
      {:ok, assign(socket, soirees: upcoming_soirees, search_query: nil)}
    else
      # Initial load - empty to speed up first render
      {:ok, assign(socket, soirees: [], search_query: nil)}
    end
  end

  def handle_event("search", %{"query" => query}, socket) do
    soirees =
      if query && query != "" do
        Soirees.search!(query)
      else
        Soirees.get_upcoming!()
      end

    {:noreply, assign(socket, soirees: soirees, search_query: query)}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="container mx-auto px-4 py-8">
        <div class="mb-8">
          <h1 class="text-3xl font-bold mb-4">Discover Soirées</h1>
          <p class="text-lg text-gray-600">
            Find and join engaging discussion events with interesting people
          </p>
          <form phx-change="search" class="mt-4">
            <div class="flex">
              <input
                type="text"
                name="query"
                value={@search_query}
                placeholder="Search soirées..."
                class="flex-grow px-4 py-2 border rounded-l focus:outline-none"
              />
              <button
                type="submit"
                class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-r"
              >
                Search
              </button>
            </div>
          </form>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          <%= if Enum.empty?(@soirees) do %>
            <div class="col-span-full text-center py-12">
              <p class="text-lg text-gray-500">No soirées found. Check back soon!</p>
            </div>
          <% else %>
            <%= for soiree <- @soirees do %>
              <div class="bg-white rounded-lg shadow-md overflow-hidden">
                <div class="relative h-48 bg-gray-200">
                  <%= if soiree.thumbnail_url do %>
                    <img
                      src={soiree.thumbnail_url}
                      alt={soiree.title}
                      class="w-full h-full object-cover"
                    />
                  <% else %>
                    <div class="w-full h-full flex items-center justify-center bg-gray-300">
                      <span class="text-gray-600 font-medium text-lg">No image</span>
                    </div>
                  <% end %>
                  <div class="absolute top-2 right-2 px-2 py-1 bg-blue-600 text-white text-xs font-semibold rounded">
                    {soiree.status}
                  </div>
                </div>
                <div class="p-4">
                  <h2 class="text-xl font-semibold mb-2">{soiree.title}</h2>
                  <p class="text-gray-600 mb-4 line-clamp-2">
                    {soiree.description || "No description provided"}
                  </p>
                  <div class="flex justify-between items-center">
                    <div class="text-sm text-gray-500">
                      {Calendar.strftime(soiree.starts_at, "%b %d, %Y · %I:%M %p")}
                    </div>
                    <button class="px-4 py-1 bg-blue-600 hover:bg-blue-700 text-white rounded">
                      Join
                    </button>
                  </div>
                </div>
              </div>
            <% end %>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
