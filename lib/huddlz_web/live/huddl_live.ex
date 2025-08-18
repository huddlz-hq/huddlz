defmodule HuddlzWeb.HuddlLive do
  use HuddlzWeb, :live_view

  alias HuddlzWeb.Layouts
  require Ash.Query

  # Authentication is optional - show cards to all but require auth for joining
  on_mount {HuddlzWeb.LiveUserAuth, :live_user_optional}

  def mount(_params, _session, socket) do
    # Get user's default location if they're logged in
    {default_location, default_radius} =
      if socket.assigns[:current_user] do
        {socket.assigns.current_user.default_location_address,
         socket.assigns.current_user.default_search_radius || 25}
      else
        {nil, 25}
      end

    # Perform initial search with user's default location if available
    huddls =
      perform_search(
        nil,
        :upcoming,
        nil,
        default_location,
        default_radius,
        socket.assigns[:current_user]
      )

    {:ok,
     assign(socket,
       huddls: huddls,
       search_query: nil,
       event_type_filter: nil,
       date_filter: "upcoming",
       location_search: default_location || "",
       search_radius: default_radius,
       location_error: nil,
       showing_location_results: default_location != nil
     )}
  end

  def handle_event("search", params, socket) do
    search_params = parse_search_params(params)
    {location_to_use, location_source} = determine_location(search_params.location, socket)

    huddls =
      perform_search(
        search_params.query,
        search_params.date_filter_atom,
        search_params.event_type_atom,
        location_to_use,
        search_params.radius,
        socket.assigns[:current_user]
      )

    socket =
      socket
      |> assign(search_query: search_params.query)
      |> assign(event_type_filter: search_params.event_type)
      |> assign(date_filter: search_params.date_filter)
      |> assign(location_search: search_params.location || "")
      |> assign(search_radius: search_params.radius)
      |> assign(huddls: huddls)
      |> assign(showing_location_results: location_to_use != nil)
      |> assign(location_source: location_source)

    {:noreply, socket}
  end

  def handle_event("clear_filters", _params, socket) do
    huddls = perform_search(nil, :upcoming, nil, nil, 25, socket.assigns[:current_user])

    socket =
      socket
      |> assign(search_query: nil)
      |> assign(event_type_filter: nil)
      |> assign(date_filter: "upcoming")
      |> assign(location_search: "")
      |> assign(search_radius: 25)
      |> assign(huddls: huddls)
      |> assign(showing_location_results: false)
      |> assign(location_source: :none)

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

    # Determine location to use
    location =
      cond do
        socket.assigns.location_search != "" ->
          socket.assigns.location_search

        socket.assigns[:current_user] && socket.assigns.current_user.default_location_address ->
          socket.assigns.current_user.default_location_address

        true ->
          nil
      end

    huddls =
      perform_search(
        socket.assigns.search_query,
        date_filter_atom,
        event_type_atom,
        location,
        socket.assigns.search_radius,
        socket.assigns[:current_user],
        offset: offset
      )

    socket =
      socket
      |> assign(huddls: huddls)

    {:noreply, socket}
  end

  defp parse_search_params(params) do
    query = if params["query"] != "", do: params["query"], else: nil
    event_type = if params["event_type"] != "", do: params["event_type"], else: nil
    date_filter = params["date_filter"] || "upcoming"
    location = if params["location"] != "", do: params["location"], else: nil
    radius = String.to_integer(params["radius"] || "25")

    event_type_atom =
      if event_type && event_type != "", do: String.to_existing_atom(event_type), else: nil

    date_filter_atom = String.to_existing_atom(date_filter)

    %{
      query: query,
      event_type: event_type,
      event_type_atom: event_type_atom,
      date_filter: date_filter,
      date_filter_atom: date_filter_atom,
      location: location,
      radius: radius
    }
  end

  defp determine_location(location, socket) do
    cond do
      location ->
        {location, :explicit}

      socket.assigns[:current_user] && socket.assigns.current_user.default_location_address ->
        {socket.assigns.current_user.default_location_address, :default}

      true ->
        {nil, :none}
    end
  end

  defp perform_search(query, date_filter, event_type, location, radius, actor, opts \\ []) do
    offset = Keyword.get(opts, :offset, 0)

    # Geocode location if provided
    {lat, lng} =
      if location do
        case Huddlz.Geocoding.geocode(location) do
          {:ok, %{lat: lat, lng: lng}} -> {lat, lng}
          {:error, _} -> {nil, nil}
        end
      else
        {nil, nil}
      end

    # Build the query for the search action
    args =
      %{
        query: query,
        date_filter: date_filter,
        event_type: event_type,
        latitude: lat,
        longitude: lng,
        radius_miles: radius
      }
      |> Enum.reject(fn {_, v} -> is_nil(v) end)
      |> Map.new()

    query =
      Huddlz.Communities.Huddl
      |> Ash.Query.for_read(:search, args)

    # Execute the query and load relationships
    case Ash.read(query, actor: actor, page: [limit: 20, offset: offset]) do
      {:ok, page} ->
        # Extract results from the page
        results = page.results

        # Load relationships and distance if searching by location
        loads = [:status, :visible_virtual_link, :group]

        loads =
          if lat && lng do
            loads ++ [distance_miles: %{latitude: lat, longitude: lng}]
          else
            loads
          end

        Ash.load!(results, loads, actor: actor)

      _ ->
        []
    end
  end

  defp humanize_filter("in_person"), do: "In Person"
  defp humanize_filter("virtual"), do: "Virtual"
  defp humanize_filter("hybrid"), do: "Hybrid"
  defp humanize_filter("upcoming"), do: "Upcoming"
  defp humanize_filter("this_week"), do: "This Week"
  defp humanize_filter("this_month"), do: "This Month"
  defp humanize_filter("past"), do: "Past"
  defp humanize_filter(other), do: Phoenix.Naming.humanize(to_string(other))

  defp format_event_type(:in_person), do: "In Person"
  defp format_event_type(:virtual), do: "Virtual"
  defp format_event_type(:hybrid), do: "Hybrid"
  defp format_event_type(_), do: "Unknown"

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

              <label for="location-search" class="sr-only">Location</label>
              <input
                id="location-search"
                type="text"
                name="location"
                value={@location_search}
                placeholder="City or address..."
                phx-debounce="300"
                class="w-64 px-4 py-2 border rounded focus:outline-none bg-base-100 text-base-content"
              />

              <label for="radius-select" class="sr-only">Search Radius</label>
              <select id="radius-select" name="radius" class="select select-bordered">
                <option value="5" selected={@search_radius == 5}>5 miles</option>
                <option value="10" selected={@search_radius == 10}>10 miles</option>
                <option value="25" selected={@search_radius == 25}>25 miles</option>
                <option value="50" selected={@search_radius == 50}>50 miles</option>
                <option value="100" selected={@search_radius == 100}>100 miles</option>
              </select>

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
                  <option value="past" selected={@date_filter == "past"}>
                    Past Events
                  </option>
                  <option value="all" selected={@date_filter == "all"}>
                    All Events
                  </option>
                </select>
              </div>
            </div>
          </form>
          
    <!-- Active Filters Display -->
          <%= if @search_query || @event_type_filter || @date_filter != "upcoming" || @showing_location_results do %>
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
              <%= if @showing_location_results do %>
                <span class="badge badge-primary">
                  Near: {if @location_search != "",
                    do: @location_search,
                    else: @current_user.default_location_address}
                  <%= if assigns[:location_source] == :default do %>
                    (default)
                  <% end %>
                </span>
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
            <%= if @showing_location_results do %>
              near {if @location_search != "",
                do: @location_search,
                else: @current_user.default_location_address}
            <% end %>
          </div>

          <%= if Enum.empty?(@huddls) do %>
            <div class="text-center py-12 bg-base-200 rounded-lg">
              <p class="text-lg text-base-content/70">
                <%= if @search_query || @event_type_filter || @date_filter != "upcoming" || @showing_location_results do %>
                  <%= if @showing_location_results do %>
                    No huddlz found within {@search_radius} miles of {if @location_search != "",
                      do: @location_search,
                      else: @current_user.default_location_address}. Try adjusting your search criteria.
                  <% else %>
                    No huddlz found matching your filters. Try adjusting your search criteria.
                  <% end %>
                <% else %>
                  No huddlz found. Check back soon!
                <% end %>
              </p>
            </div>
          <% else %>
            <!-- Huddl Cards Grid -->
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              <%= for huddl <- @huddls do %>
                <.link navigate={~p"/groups/#{huddl.group.slug}/huddlz/#{huddl.id}"}>
                  <div class="card bg-base-100 shadow-xl hover:shadow-2xl transition-shadow cursor-pointer">
                    <%= if huddl.thumbnail_url do %>
                      <figure>
                        <img
                          src={huddl.thumbnail_url}
                          alt={huddl.title}
                          class="w-full h-48 object-cover"
                        />
                      </figure>
                    <% end %>
                    <div class="card-body">
                      <h3 class="card-title">
                        {huddl.title}
                        <%= if huddl.status == :in_progress do %>
                          <span class="badge badge-success">In Progress</span>
                        <% end %>
                      </h3>

                      <div class="flex items-center gap-2 text-sm text-base-content/70">
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            stroke-width="2"
                            d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"
                          />
                        </svg>
                        {huddl.group.name}
                      </div>

                      <div class="flex items-center gap-2 text-sm text-base-content/70">
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            stroke-width="2"
                            d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
                          />
                        </svg>
                        {Calendar.strftime(huddl.starts_at, "%b %d, %Y at %I:%M %p")}
                      </div>

                      <div class="flex items-center gap-2 text-sm">
                        <span class={"badge " <> event_type_badge_class(huddl.event_type)}>
                          {format_event_type(huddl.event_type)}
                        </span>
                        <%= if huddl.is_private do %>
                          <span class="badge badge-warning">Private</span>
                        <% end %>
                      </div>

                      <%= if huddl.physical_location do %>
                        <div class="flex items-center gap-2 text-sm text-base-content/70">
                          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path
                              stroke-linecap="round"
                              stroke-linejoin="round"
                              stroke-width="2"
                              d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"
                            />
                            <path
                              stroke-linecap="round"
                              stroke-linejoin="round"
                              stroke-width="2"
                              d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"
                            />
                          </svg>
                          <span class="truncate">{huddl.physical_location}</span>
                          <%= if is_float(huddl.distance_miles) do %>
                            <span class="text-xs">({Float.round(huddl.distance_miles, 1)} mi)</span>
                          <% end %>
                        </div>
                      <% end %>

                      <%= if huddl.description do %>
                        <p class="text-sm text-base-content/70 line-clamp-2">
                          {huddl.description}
                        </p>
                      <% end %>

                      <div class="card-actions justify-between items-center mt-4">
                        <div class="text-sm text-base-content/70">
                          {huddl.rsvp_count} {if huddl.rsvp_count == 1,
                            do: "attendee",
                            else: "attendees"}
                        </div>
                        <div class="btn btn-primary btn-sm">View Details</div>
                      </div>
                    </div>
                  </div>
                </.link>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp event_type_badge_class(:in_person), do: "badge-accent"
  defp event_type_badge_class(:virtual), do: "badge-info"
  defp event_type_badge_class(:hybrid), do: "badge-secondary"
  defp event_type_badge_class(_), do: ""
end
