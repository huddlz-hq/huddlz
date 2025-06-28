defmodule HuddlzWeb.HuddlLive do
  use HuddlzWeb, :live_view

  alias Huddlz.Communities
  alias HuddlzWeb.Layouts
  require Ash.Query

  # Authentication is optional - show cards to all but require auth for joining
  on_mount {HuddlzWeb.LiveUserAuth, :live_user_optional}

  def mount(_params, _session, socket) do
    # Load upcoming huddls (includes in-progress) with pagination
    page =
      Communities.search_huddlz(nil, :upcoming, nil,
        actor: socket.assigns[:current_user],
        page: [limit: 20, offset: 0, count: true]
      )

    huddls =
      case page do
        {:ok, %{results: results}} ->
          Ash.load!(results, [:status, :visible_virtual_link, :group],
            actor: socket.assigns[:current_user]
          )

        _ ->
          []
      end

    {:ok,
     assign(socket,
       huddls: huddls,
       page_info: extract_page_info(page),
       search_query: nil,
       event_type_filter: nil,
       date_filter: "upcoming"
     )}
  end

  def handle_event("search", params, socket) do
    query = if params["query"] != "", do: params["query"], else: nil
    event_type = if params["event_type"] != "", do: params["event_type"], else: nil
    date_filter = params["date_filter"] || "upcoming"

    # Convert string values to atoms for the search action
    event_type_atom =
      if event_type && event_type != "", do: String.to_existing_atom(event_type), else: nil

    date_filter_atom = String.to_existing_atom(date_filter)

    page =
      Communities.search_huddlz(query, date_filter_atom, event_type_atom,
        actor: socket.assigns[:current_user],
        page: [limit: 20, offset: 0, count: true]
      )

    huddls =
      case page do
        {:ok, %{results: results}} ->
          Ash.load!(results, [:status, :visible_virtual_link, :group],
            actor: socket.assigns[:current_user]
          )

        _ ->
          []
      end

    socket =
      socket
      |> assign(search_query: query)
      |> assign(event_type_filter: event_type)
      |> assign(date_filter: date_filter)
      |> assign(huddls: huddls)
      |> assign(page_info: extract_page_info(page))

    {:noreply, socket}
  end

  def handle_event("clear_filters", _params, socket) do
    page =
      Communities.search_huddlz(nil, :upcoming, nil,
        actor: socket.assigns[:current_user],
        page: [limit: 20, offset: 0, count: true]
      )

    huddls =
      case page do
        {:ok, %{results: results}} ->
          Ash.load!(results, [:status, :visible_virtual_link, :group],
            actor: socket.assigns[:current_user]
          )

        _ ->
          []
      end

    socket =
      socket
      |> assign(search_query: nil)
      |> assign(event_type_filter: nil)
      |> assign(date_filter: "upcoming")
      |> assign(huddls: huddls)
      |> assign(page_info: extract_page_info(page))

    {:noreply, socket}
  end

  def handle_event("change_page", %{"page" => page_str}, socket) do
    page_num = String.to_integer(page_str)
    offset = (page_num - 1) * 20

    # Convert filter values to atoms
    event_type_atom =
      if socket.assigns.event_type_filter && socket.assigns.event_type_filter != "",
        do: String.to_atom(socket.assigns.event_type_filter),
        else: nil

    date_filter_atom = String.to_atom(socket.assigns.date_filter)

    page =
      Communities.search_huddlz(
        socket.assigns.search_query,
        date_filter_atom,
        event_type_atom,
        actor: socket.assigns[:current_user],
        page: [limit: 20, offset: offset, count: true]
      )

    huddls =
      case page do
        {:ok, %{results: results}} ->
          Ash.load!(results, [:status, :visible_virtual_link, :group],
            actor: socket.assigns[:current_user]
          )

        _ ->
          []
      end

    socket =
      socket
      |> assign(huddls: huddls)
      |> assign(page_info: Map.put(extract_page_info(page), :current_page, page_num))

    {:noreply, socket}
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

          <form phx-change="search" phx-submit="search" class="mt-6 space-y-4">
            <div class="flex gap-2">
              <label for="search-query" class="sr-only">Search huddlz</label>
              <input
                id="search-query"
                type="text"
                name="query"
                value={@search_query}
                placeholder="Search huddlz..."
                phx-debounce="300"
                class="flex-grow px-4 py-2 border rounded focus:outline-none bg-base-100 text-base-content"
              />
              <button type="submit" class="btn btn-primary px-4 py-2">
                Search
              </button>
            </div>

            <div class="flex flex-wrap gap-4">
              <!-- Event Type Filter -->
              <div class="form-control">
                <label for="event-type" class="label">
                  <span class="label-text">Event Type</span>
                </label>
                <select id="event-type" name="event_type" class="select select-bordered">
                  <option value="">All Types</option>
                  <option value="in_person" selected={@event_type_filter == "in_person"}>
                    In Person
                  </option>
                  <option value="virtual" selected={@event_type_filter == "virtual"}>
                    Virtual
                  </option>
                  <option value="hybrid" selected={@event_type_filter == "hybrid"}>
                    Hybrid
                  </option>
                </select>
              </div>
              
    <!-- Date Filter -->
              <div class="form-control">
                <label for="date-range" class="label">
                  <span class="label-text">Date Range</span>
                </label>
                <select id="date-range" name="date_filter" class="select select-bordered">
                  <option value="upcoming" selected={@date_filter == "upcoming"}>
                    All Upcoming
                  </option>
                  <option value="this_week" selected={@date_filter == "this_week"}>
                    This Week
                  </option>
                  <option value="this_month" selected={@date_filter == "this_month"}>
                    This Month
                  </option>
                </select>
              </div>
            </div>
          </form>
          
    <!-- Active Filters Display -->
          <%= if @search_query || @event_type_filter || @date_filter != "upcoming" do %>
            <div class="mt-4 flex items-center gap-2">
              <span class="text-sm">Active filters:</span>
              <%= if @search_query do %>
                <span class="badge badge-primary">Search: {@search_query}</span>
              <% end %>
              <%= if @event_type_filter do %>
                <span class="badge badge-primary">Type: {humanize_filter(@event_type_filter)}</span>
              <% end %>
              <%= if @date_filter != "upcoming" do %>
                <span class="badge badge-primary">Date: {humanize_filter(@date_filter)}</span>
              <% end %>
              <button phx-click="clear_filters" class="btn btn-xs btn-ghost">
                Clear all
              </button>
            </div>
          <% end %>
        </div>

        <div class="w-full">
          <!-- Results count -->
          <div class="mb-4 text-sm text-base-content/70">
            Found {length(@huddls)} {if length(@huddls) == 1, do: "huddl", else: "huddlz"}
          </div>

          <%= if Enum.empty?(@huddls) do %>
            <div class="text-center py-12 bg-base-200 rounded-lg">
              <p class="text-lg text-base-content/70">
                <%= if @search_query || @event_type_filter || @date_filter != "upcoming" do %>
                  No huddlz found matching your filters. Try adjusting your search criteria.
                <% else %>
                  No huddlz found. Check back soon!
                <% end %>
              </p>
            </div>
          <% else %>
            <div class="space-y-4">
              <%= for huddl <- @huddls do %>
                <.huddl_card huddl={huddl} show_group={true} />
              <% end %>
            </div>
            
    <!-- Pagination -->
            <%= if @page_info.total_pages > 1 do %>
              <.pagination
                current_page={@page_info.current_page}
                total_pages={@page_info.total_pages}
                event_name="change_page"
              />
            <% end %>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp humanize_filter(filter) do
    filter
    |> to_string()
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp extract_page_info({:ok, %Ash.Page.Offset{count: count, limit: limit, offset: offset}}) do
    total_pages = if count && count > 0, do: ceil(count / limit), else: 1
    current_page = if offset && limit > 0, do: div(offset, limit) + 1, else: 1

    %{
      total_pages: total_pages,
      current_page: current_page,
      total_count: count || 0
    }
  end

  defp extract_page_info({:ok, %Ash.Page.Keyset{count: count, limit: limit}}) do
    total_pages = if count && count > 0, do: ceil(count / limit), else: 1

    %{
      total_pages: total_pages,
      current_page: 1,
      total_count: count || 0
    }
  end

  defp extract_page_info(_) do
    %{
      total_pages: 1,
      current_page: 1,
      total_count: 0
    }
  end
end
