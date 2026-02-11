defmodule HuddlzWeb.HuddlLive do
  @moduledoc """
  LiveView for searching and filtering huddlz across all groups.
  """
  use HuddlzWeb, :live_view

  alias Huddlz.Communities
  alias Huddlz.Communities.Group
  alias HuddlzWeb.Layouts
  require Ash.Query

  # Authentication is optional - show cards to all but require auth for joining
  on_mount {HuddlzWeb.LiveUserAuth, :live_user_optional}

  def mount(_params, _session, socket) do
    user = socket.assigns[:current_user]

    # Pre-fill location from user profile if available
    {location_text, location_lat, location_lng} =
      if user && user.home_location do
        {user.home_location, user.home_latitude, user.home_longitude}
      else
        {nil, nil, nil}
      end

    location_active = not is_nil(location_lat) and not is_nil(location_lng)

    socket =
      assign(socket,
        search_query: nil,
        event_type_filter: nil,
        date_filter: "upcoming",
        location_text: location_text,
        location_lat: location_lat,
        location_lng: location_lng,
        location_active: location_active,
        distance_miles: 25,
        groups: list_public_groups()
      )

    socket = perform_search(socket)

    {:ok, socket}
  end

  def handle_event("search", params, socket) do
    query = if params["query"] != "", do: params["query"], else: nil
    event_type = if params["event_type"] != "", do: params["event_type"], else: nil
    date_filter = params["date_filter"] || "upcoming"
    location_text = params["location"]
    distance_miles = parse_distance(params["distance_miles"])

    socket =
      socket
      |> maybe_geocode_location(location_text)
      |> assign(search_query: query)
      |> assign(event_type_filter: event_type)
      |> assign(date_filter: date_filter)
      |> assign(distance_miles: distance_miles)
      |> perform_search()

    {:noreply, socket}
  end

  def handle_event("clear_filters", _params, socket) do
    socket =
      socket
      |> assign(
        search_query: nil,
        event_type_filter: nil,
        date_filter: "upcoming",
        location_text: nil,
        location_lat: nil,
        location_lng: nil,
        location_active: false,
        distance_miles: 25
      )
      |> perform_search()

    {:noreply, socket}
  end

  def handle_event("change_page", %{"page" => page_str}, socket) do
    page_num = String.to_integer(page_str)
    socket = perform_search(socket, offset: (page_num - 1) * 20)
    {:noreply, socket}
  end

  defp perform_search(socket, opts \\ []) do
    offset = Keyword.get(opts, :offset, 0)

    event_type_atom =
      if socket.assigns.event_type_filter && socket.assigns.event_type_filter != "",
        do: String.to_existing_atom(socket.assigns.event_type_filter),
        else: nil

    date_filter_atom = String.to_existing_atom(socket.assigns.date_filter)

    {search_lat, search_lng, distance} =
      if socket.assigns.location_active do
        {socket.assigns.location_lat, socket.assigns.location_lng, socket.assigns.distance_miles}
      else
        {nil, nil, nil}
      end

    page =
      Communities.search_huddlz(
        socket.assigns.search_query,
        date_filter_atom,
        event_type_atom,
        search_lat,
        search_lng,
        distance,
        actor: socket.assigns[:current_user],
        page: [limit: 20, offset: offset, count: true]
      )

    {huddls, distances} = load_results_with_distances(page, socket)

    page_info = extract_page_info(page)

    page_info =
      if offset > 0, do: Map.put(page_info, :current_page, div(offset, 20) + 1), else: page_info

    socket
    |> assign(huddls: Enum.zip(huddls, distances))
    |> assign(page_info: page_info)
  end

  defp maybe_geocode_location(socket, "") do
    assign(socket,
      location_text: nil,
      location_lat: nil,
      location_lng: nil,
      location_active: false
    )
  end

  defp maybe_geocode_location(socket, location_text) do
    current = socket.assigns.location_text || ""

    if location_text == current do
      socket
    else
      geocode_location(socket, location_text)
    end
  end

  defp geocode_location(socket, location_text) do
    case Huddlz.Geocoding.geocode(location_text) do
      {:ok, %{latitude: lat, longitude: lng}} ->
        assign(socket,
          location_text: location_text,
          location_lat: lat,
          location_lng: lng,
          location_active: true
        )

      {:error, :not_found} ->
        socket
        |> put_flash(:error, "Could not find that location. Try a more specific address.")
        |> assign(location_text: location_text, location_lat: nil, location_lng: nil, location_active: false)

      {:error, _} ->
        socket
        |> put_flash(:error, "Location search is currently unavailable.")
        |> assign(location_text: location_text, location_lat: nil, location_lng: nil, location_active: false)
    end
  end

  defp load_results_with_distances({:ok, %{results: results}}, socket) do
    loaded =
      Ash.load!(
        results,
        [:status, :rsvp_count, :visible_virtual_link, :display_image_url, :group],
        actor: socket.assigns[:current_user]
      )

    dists = compute_distances(loaded, socket)
    {loaded, dists}
  end

  defp load_results_with_distances(_, _socket), do: {[], []}

  defp compute_distances(huddls, %{assigns: %{location_active: false}}) do
    List.duplicate(nil, length(huddls))
  end

  defp compute_distances(huddls, %{assigns: assigns}) do
    origin = {assigns.location_lat, assigns.location_lng}

    Enum.map(huddls, fn h ->
      if h.latitude && h.longitude,
        do: Huddlz.Geocoding.distance_miles(origin, {h.latitude, h.longitude}),
        else: nil
    end)
  end

  defp parse_distance(nil), do: 25
  defp parse_distance(""), do: 25
  defp parse_distance(val) when is_binary(val), do: String.to_integer(val)
  defp parse_distance(val) when is_integer(val), do: val

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div>
        <div class="mb-8">
          <form phx-change="search" phx-submit="search">
            <div class="flex flex-wrap items-end gap-2">
              <div class="flex-grow min-w-[200px]">
                <label for="search-query" class="sr-only">Search huddlz</label>
                <input
                  id="search-query"
                  type="text"
                  name="query"
                  value={@search_query}
                  placeholder="Find your huddl"
                  phx-debounce="300"
                  class="w-full h-12 pl-0 pr-4 border-0 border-b border-base-300 bg-transparent text-base focus:outline-none focus:ring-0 focus:border-primary transition-colors placeholder:text-base-content/30"
                />
              </div>
              <label for="event-type" class="sr-only">Event Type</label>
              <select
                id="event-type"
                name="event_type"
                class="h-12 px-3 border border-base-300 bg-base-100 text-sm focus:outline-none focus:ring-2 focus:ring-primary/50 focus:border-primary transition-colors"
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
                class="h-12 px-3 border border-base-300 bg-base-100 text-sm focus:outline-none focus:ring-2 focus:ring-primary/50 focus:border-primary transition-colors"
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
                class="h-12 px-6 bg-primary text-primary-content font-medium btn-neon active:scale-[0.98] transition-all"
              >
                Search
              </button>
            </div>
            <div class="flex flex-wrap items-end gap-2 mt-2">
              <div class="flex-grow min-w-[200px] relative">
                <label for="location-input" class="sr-only">Location</label>
                <.icon
                  name="hero-map-pin"
                  class="absolute left-0 top-1/2 -translate-y-1/2 h-4 w-4 text-base-content/30"
                />
                <input
                  id="location-input"
                  type="text"
                  name="location"
                  value={@location_text}
                  placeholder="City, State"
                  phx-debounce="800"
                  class="w-full h-12 pl-6 pr-4 border-0 border-b border-base-300 bg-transparent text-base focus:outline-none focus:ring-0 focus:border-primary transition-colors placeholder:text-base-content/30"
                />
              </div>
              <label for="distance-radius" class="sr-only">Distance</label>
              <select
                id="distance-radius"
                name="distance_miles"
                disabled={!@location_active}
                class={[
                  "h-12 px-3 border border-base-300 bg-base-100 text-sm focus:outline-none focus:ring-2 focus:ring-primary/50 focus:border-primary transition-colors",
                  !@location_active && "opacity-50"
                ]}
              >
                <option value="10" selected={@distance_miles == 10}>10 miles</option>
                <option value="25" selected={@distance_miles == 25}>25 miles</option>
                <option value="50" selected={@distance_miles == 50}>50 miles</option>
                <option value="100" selected={@distance_miles == 100}>100 miles</option>
              </select>
            </div>
          </form>

          <%= if @search_query || @event_type_filter || @date_filter != "upcoming" || @location_active do %>
            <div class="mt-3 flex flex-wrap items-center gap-2">
              <span class="text-sm text-base-content/40">Filters:</span>
              <%= if @search_query do %>
                <span class="text-xs px-2.5 py-1 bg-secondary/10 text-secondary font-medium inline-flex items-center">
                  Search: {@search_query}
                </span>
              <% end %>
              <%= if @event_type_filter do %>
                <span class="text-xs px-2.5 py-1 bg-secondary/10 text-secondary font-medium inline-flex items-center">
                  Type: {humanize_filter(@event_type_filter)}
                </span>
              <% end %>
              <%= if @date_filter != "upcoming" do %>
                <span class="text-xs px-2.5 py-1 bg-secondary/10 text-secondary font-medium inline-flex items-center">
                  Date: {humanize_filter(@date_filter)}
                </span>
              <% end %>
              <%= if @location_active do %>
                <span class="text-xs px-2.5 py-1 bg-primary/10 text-primary font-medium inline-flex items-center gap-1">
                  <.icon name="hero-map-pin" class="h-3 w-3" />
                  {@location_text} · {@distance_miles} mi
                </span>
              <% end %>
              <button
                phx-click="clear_filters"
                class="text-xs text-primary hover:underline font-medium"
              >
                Clear all
              </button>
            </div>
          <% end %>
        </div>

        <div class="w-full">
          <%= if Enum.empty?(@huddls) do %>
            <%= if @search_query || @event_type_filter || @date_filter != "upcoming" || @location_active do %>
              <div class="border border-dashed border-base-300 p-12 text-center">
                <p class="text-lg text-base-content/50">
                  No huddlz found matching your filters. Try adjusting your search criteria.
                </p>
              </div>
            <% else %>
              <div class="text-center py-8">
                <p class="text-base-content/40">No upcoming huddlz right now.</p>
              </div>

              <%= if @groups != [] do %>
                <div class="mt-6" id="groups-fallback">
                  <h2 class="font-display text-lg tracking-tight text-glow mb-4">
                    Groups you can explore
                  </h2>
                  <div class="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
                    <%= for group <- @groups do %>
                      <.group_card group={group} />
                    <% end %>
                  </div>
                  <div class="text-center mt-4">
                    <.link
                      navigate={~p"/groups"}
                      class="text-sm text-primary hover:underline font-medium"
                    >
                      View all groups
                    </.link>
                  </div>
                </div>
              <% end %>
            <% end %>
          <% else %>
            <div class="mb-4 text-sm text-base-content/40">
              Found {@page_info.total_count} {if @page_info.total_count == 1,
                do: "huddl",
                else: "huddlz"}
            </div>
            <div class="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
              <%= for {huddl, distance} <- @huddls do %>
                <.huddl_card huddl={huddl} show_group={true} distance={distance} />
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
    case Group
         |> Ash.Query.filter(is_public: true)
         |> Ash.Query.load(:current_image_url)
         |> Ash.Query.limit(6)
         |> Ash.read() do
      {:ok, groups} -> groups
      {:error, _} -> []
    end
  end
end
