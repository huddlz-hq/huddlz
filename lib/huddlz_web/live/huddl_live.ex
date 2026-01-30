defmodule HuddlzWeb.HuddlLive do
  @moduledoc """
  LiveView for searching and filtering huddlz across all groups.
  """
  use HuddlzWeb, :live_view

  alias Huddlz.Communities
  alias Huddlz.Communities.Group
  alias Huddlz.Storage.GroupImages
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
          Ash.load!(results, [:status, :visible_virtual_link, :display_image_url, :group],
            actor: socket.assigns[:current_user]
          )

        _ ->
          []
      end

    groups = list_public_groups()

    {:ok,
     assign(socket,
       huddls: huddls,
       groups: groups,
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
          Ash.load!(results, [:status, :visible_virtual_link, :display_image_url, :group],
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
          Ash.load!(results, [:status, :visible_virtual_link, :display_image_url, :group],
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
          Ash.load!(results, [:status, :visible_virtual_link, :display_image_url, :group],
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
      <div class="container mx-auto px-4 py-4">
        <div class="mb-6">
          <h1 class="text-2xl font-bold mb-4">Find your huddl</h1>

          <form phx-change="search" phx-submit="search">
            <div class="flex flex-wrap items-end gap-2">
              <div class="flex-grow min-w-[200px]">
                <label for="search-query" class="sr-only">Search huddlz</label>
                <input
                  id="search-query"
                  type="text"
                  name="query"
                  value={@search_query}
                  placeholder="Search huddlz..."
                  phx-debounce="300"
                  class="w-full h-12 px-4 rounded-lg border border-base-300 bg-base-100 text-base focus:outline-none focus:ring-2 focus:ring-primary/50 focus:border-primary transition-colors"
                />
              </div>
              <label for="event-type" class="sr-only">Event Type</label>
              <select
                id="event-type"
                name="event_type"
                class="h-12 px-3 rounded-lg border border-base-300 bg-base-100 text-sm focus:outline-none focus:ring-2 focus:ring-primary/50 focus:border-primary transition-colors"
              >
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
              <label for="date-range" class="sr-only">Date Range</label>
              <select
                id="date-range"
                name="date_filter"
                class="h-12 px-3 rounded-lg border border-base-300 bg-base-100 text-sm focus:outline-none focus:ring-2 focus:ring-primary/50 focus:border-primary transition-colors"
              >
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
              <button
                type="submit"
                class="h-12 px-6 rounded-lg bg-primary text-primary-content font-medium hover:brightness-110 active:scale-[0.98] transition-all"
              >
                Search
              </button>
            </div>
          </form>

          <%= if @search_query || @event_type_filter || @date_filter != "upcoming" do %>
            <div class="mt-3 flex flex-wrap items-center gap-2">
              <span class="text-sm text-base-content/60">Filters:</span>
              <%= if @search_query do %>
                <span class="badge badge-primary badge-sm">Search: {@search_query}</span>
              <% end %>
              <%= if @event_type_filter do %>
                <span class="badge badge-primary badge-sm">
                  Type: {humanize_filter(@event_type_filter)}
                </span>
              <% end %>
              <%= if @date_filter != "upcoming" do %>
                <span class="badge badge-primary badge-sm">
                  Date: {humanize_filter(@date_filter)}
                </span>
              <% end %>
              <button phx-click="clear_filters" class="btn btn-xs btn-ghost">
                Clear all
              </button>
            </div>
          <% end %>
        </div>

        <div class="w-full">
          <%= if Enum.empty?(@huddls) do %>
            <%= if @search_query || @event_type_filter || @date_filter != "upcoming" do %>
              <div class="text-center py-12 bg-base-200 rounded-lg">
                <p class="text-lg text-base-content/70">
                  No huddlz found matching your filters. Try adjusting your search criteria.
                </p>
              </div>
            <% else %>
              <div class="text-center py-8">
                <p class="text-base-content/60">No upcoming huddlz right now.</p>
              </div>

              <%= if @groups != [] do %>
                <div class="mt-6" id="groups-fallback">
                  <h2 class="text-lg font-semibold mb-4">Groups you can explore</h2>
                  <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
                    <%= for group <- @groups do %>
                      <.link
                        navigate={~p"/groups/#{group.slug}"}
                        class="card bg-base-100 shadow-md hover:shadow-lg transition-shadow"
                      >
                        <figure class="aspect-video">
                          <%= if group.current_image_url do %>
                            <img
                              src={GroupImages.url(group.current_image_url)}
                              alt={group.name}
                              class="w-full h-full object-cover"
                            />
                          <% else %>
                            <div class="w-full h-full bg-gradient-to-br from-primary/20 to-secondary/20 flex items-center justify-center">
                              <span class="text-xl font-bold text-base-content/30 text-center px-4 line-clamp-2">
                                {group.name}
                              </span>
                            </div>
                          <% end %>
                        </figure>
                        <div class="card-body p-4">
                          <h3 class="font-semibold">{group.name}</h3>
                          <p class="text-sm text-base-content/60 line-clamp-2">
                            {group.description || "No description provided."}
                          </p>
                          <p :if={group.location} class="text-xs text-base-content/50 mt-1">
                            <.icon name="hero-map-pin" class="h-3 w-3 inline" /> {group.location}
                          </p>
                        </div>
                      </.link>
                    <% end %>
                  </div>
                  <div class="text-center mt-4">
                    <.link navigate={~p"/groups"} class="text-sm text-primary hover:underline">
                      View all groups
                    </.link>
                  </div>
                </div>
              <% end %>
            <% end %>
          <% else %>
            <div class="mb-4 text-sm text-base-content/60">
              Found {length(@huddls)} {if length(@huddls) == 1, do: "huddl", else: "huddlz"}
            </div>
            <div class="space-y-4">
              <%= for huddl <- @huddls do %>
                <.huddl_card huddl={huddl} show_group={true} />
              <% end %>
            </div>

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

  defp list_public_groups do
    Group
    |> Ash.Query.filter(is_public: true)
    |> Ash.Query.load(:current_image_url)
    |> Ash.Query.limit(6)
    |> Ash.read!()
  rescue
    _ -> []
  end
end
