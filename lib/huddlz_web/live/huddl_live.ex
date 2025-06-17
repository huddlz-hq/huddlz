defmodule HuddlzWeb.HuddlLive do
  use HuddlzWeb, :live_view

  alias HuddlzWeb.Layouts
  require Ash.Query

  # Authentication is optional - show cards to all but require auth for joining
  on_mount {HuddlzWeb.LiveUserAuth, :live_user_optional}

  def mount(_params, _session, socket) do
    # Use advanced_search to get upcoming huddls by default
    huddls =
      Huddlz.Communities.Huddl
      |> Ash.Query.for_read(:advanced_search, %{
        date_filter: :any_day,
        type_filter: :any_type,
        status_filter: :any_status
      })
      |> Ash.read!(actor: socket.assigns[:current_user])
      |> Ash.load!([:status, :visible_virtual_link, :group], actor: socket.assigns[:current_user])

    {:ok,
     assign(socket,
       # Search inputs
       keyword_search: "",
       location_search: "",

       # Filters
       date_filter: "any_day",
       type_filter: "any_type",
       distance_filter: "25",

       # Results
       huddls: huddls,
       search_performed: false,

       # Geolocation data
       user_location: nil,
       location_error: nil
     )}
  end

  def handle_event("search", params, socket) do
    socket =
      socket
      |> assign(
        keyword_search: params["keyword"] || "",
        location_search: params["location"] || "",
        search_performed: true
      )
      |> perform_search()

    {:noreply, socket}
  end

  def handle_event("update_filters", params, socket) do
    socket =
      socket
      |> assign(
        date_filter: params["date_filter"] || socket.assigns.date_filter,
        type_filter: params["type_filter"] || socket.assigns.type_filter,
        distance_filter: params["distance_filter"] || socket.assigns.distance_filter
      )
      |> perform_search()

    {:noreply, socket}
  end

  def handle_event("clear_search", _params, socket) do
    # Reset to default search showing upcoming huddls
    huddls =
      Huddlz.Communities.Huddl
      |> Ash.Query.for_read(:advanced_search, %{
        date_filter: :any_day,
        type_filter: :any_type,
        status_filter: :any_status
      })
      |> Ash.read!(actor: socket.assigns[:current_user])
      |> Ash.load!([:status, :visible_virtual_link, :group], actor: socket.assigns[:current_user])

    {:noreply,
     assign(socket,
       keyword_search: "",
       location_search: "",
       date_filter: "any_day",
       type_filter: "any_type",
       distance_filter: "25",
       huddls: huddls,
       search_performed: false
     )}
  end

  def handle_event("clear_filter", %{"filter" => filter}, socket) do
    socket =
      case filter do
        "keyword" ->
          assign(socket, keyword_search: "")

        "type" ->
          assign(socket, type_filter: "any_type")

        "date" ->
          assign(socket, date_filter: "any_day")

        "location" ->
          assign(socket, location_search: "", distance_filter: "25")

        _ ->
          socket
      end
      |> perform_search()

    {:noreply, socket}
  end

  defp perform_search(socket) do
    %{
      keyword_search: keyword,
      location_search: location,
      date_filter: date_filter,
      type_filter: type_filter,
      distance_filter: distance,
      current_user: current_user
    } = socket.assigns

    # Convert string filters to atoms
    date_filter_atom = String.to_existing_atom(date_filter)
    type_filter_atom = String.to_existing_atom(type_filter)
    radius = String.to_integer(distance)

    # Handle location geocoding
    {lat, lng} =
      if location == "" do
        {nil, nil}
      else
        case Huddlz.Geocoding.geocode(location) do
          {:ok, %{lat: lat, lng: lng}} -> {lat, lng}
          {:error, _} -> {nil, nil}
        end
      end

    # Build query using advanced_search
    query =
      Huddlz.Communities.Huddl
      |> Ash.Query.for_read(:advanced_search, %{
        query: if(keyword == "", do: nil, else: keyword),
        date_filter: date_filter_atom,
        type_filter: type_filter_atom,
        latitude: lat,
        longitude: lng,
        radius_miles: radius
      })

    # Execute query
    huddls = Ash.read!(query, actor: current_user)

    # Load relationships and distance calculation if location search
    huddls =
      if lat && lng do
        Ash.load!(
          huddls,
          [
            :status,
            :visible_virtual_link,
            :group,
            distance_miles: %{latitude: lat, longitude: lng}
          ],
          actor: current_user
        )
        |> Enum.sort_by(& &1.distance_miles)
      else
        Ash.load!(huddls, [:status, :visible_virtual_link, :group], actor: current_user)
      end

    assign(socket, huddls: huddls)
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="container mx-auto px-4 py-8 max-w-7xl">
        <!-- Search Header -->
        <div class="mb-6">
          <h1 class="text-3xl font-bold mb-2">Find your huddl</h1>
          <p class="text-base text-base-content/70">
            Find and join engaging discussion events with interesting people
          </p>
        </div>
        
    <!-- Search Form -->
        <form id="search-form" phx-change="search" phx-submit="search" class="mb-6">
          <div class="flex flex-col lg:flex-row gap-4">
            <!-- Search Input Group -->
            <div class="flex-1">
              <div class="join w-full">
                <!-- Keyword Search -->
                <div class="flex-1 relative">
                  <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none z-10">
                    <svg
                      class="h-5 w-5 text-base-content/50"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
                      />
                    </svg>
                  </div>
                  <input
                    type="text"
                    id="keyword-search"
                    name="keyword"
                    value={@keyword_search}
                    placeholder="Search huddlz..."
                    phx-debounce="300"
                    class="input input-bordered join-item w-full pl-10"
                  />
                  <label for="keyword-search" class="sr-only">Search huddlz</label>
                </div>
                
    <!-- Location Search -->
                <div class="flex-1 relative">
                  <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none z-10">
                    <svg
                      class="h-5 w-5 text-base-content/50"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
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
                  </div>
                  <input
                    type="text"
                    id="location-search"
                    name="location"
                    value={@location_search}
                    placeholder="City or zip code"
                    class="input input-bordered join-item w-full pl-10"
                    phx-debounce="300"
                  />
                  <label for="location-search" class="sr-only">City or zip code</label>
                </div>
                
    <!-- Search Button -->
                <button type="submit" class="btn btn-primary join-item">
                  Search huddlz
                </button>
              </div>
            </div>
          </div>
        </form>
        
    <!-- Filters and Controls -->
        <form id="filters-form" phx-change="update_filters" class="mb-6 space-y-4">
          <!-- Filter Row -->
          <div class="flex flex-wrap items-center gap-2">
            <!-- Date Range Filter -->
            <label for="date-range" class="sr-only">Date Range</label>
            <select id="date-range" name="date_filter" class="select select-bordered select-sm">
              <option value="any_day" selected={@date_filter == "any_day"}>Any day</option>
              <option value="starting_soon" selected={@date_filter == "starting_soon"}>
                Starting soon
              </option>
              <option value="today" selected={@date_filter == "today"}>Today</option>
              <option value="tomorrow" selected={@date_filter == "tomorrow"}>Tomorrow</option>
              <option value="this_week" selected={@date_filter == "this_week"}>This Week</option>
              <option value="this_weekend" selected={@date_filter == "this_weekend"}>
                This weekend
              </option>
              <option value="next_week" selected={@date_filter == "next_week"}>Next week</option>
              <option value="this_month" selected={@date_filter == "this_month"}>This Month</option>
              <option value="past_events" selected={@date_filter == "past_events"}>
                Past events
              </option>
            </select>
            
    <!-- Event Type Filter -->
            <label for="event-type" class="sr-only">Event Type</label>
            <select id="event-type" name="type_filter" class="select select-bordered select-sm">
              <option value="any_type" selected={@type_filter == "any_type"}>Any type</option>
              <option value="online" selected={@type_filter == "online"}>Virtual</option>
              <option value="in_person" selected={@type_filter == "in_person"}>In person</option>
            </select>
            
    <!-- Distance Filter -->
            <label for="distance-filter" class="sr-only">Distance</label>
            <select
              id="distance-filter"
              name="distance_filter"
              class="select select-bordered select-sm"
              disabled={@location_search == ""}
            >
              <option value="5" selected={@distance_filter == "5"}>Within 5 miles</option>
              <option value="10" selected={@distance_filter == "10"}>Within 10 miles</option>
              <option value="25" selected={@distance_filter == "25"}>Within 25 miles</option>
              <option value="50" selected={@distance_filter == "50"}>Within 50 miles</option>
              <option value="100" selected={@distance_filter == "100"}>Within 100 miles</option>
            </select>
          </div>
          
    <!-- Active Filters Display -->
          <div class="flex flex-wrap items-center gap-2">
            <%= if @keyword_search != "" do %>
              <div class="badge badge-outline gap-2">
                Search: {@keyword_search}
                <button
                  phx-click="clear_filter"
                  phx-value-filter="keyword"
                  class="btn btn-ghost btn-xs btn-circle"
                >
                  ×
                </button>
              </div>
            <% end %>

            <%= if @type_filter != "any_type" do %>
              <div class="badge badge-outline gap-2">
                Type: {type_filter_label(@type_filter)}
                <button
                  phx-click="clear_filter"
                  phx-value-filter="type"
                  class="btn btn-ghost btn-xs btn-circle"
                >
                  ×
                </button>
              </div>
            <% end %>

            <%= if @date_filter != "any_day" do %>
              <div class="badge badge-outline gap-2">
                Date: {date_filter_label(@date_filter)}
                <button
                  phx-click="clear_filter"
                  phx-value-filter="date"
                  class="btn btn-ghost btn-xs btn-circle"
                >
                  ×
                </button>
              </div>
            <% end %>

            <%= if @location_search != "" do %>
              <div class="badge badge-outline gap-2">
                Location: {@location_search} ({@distance_filter} mi)
                <button
                  phx-click="clear_filter"
                  phx-value-filter="location"
                  class="btn btn-ghost btn-xs btn-circle"
                >
                  ×
                </button>
              </div>
            <% end %>
            
    <!-- Clear All Button -->
            <%= if @keyword_search != "" || @date_filter != "any_day" || @type_filter != "any_type" || @location_search != "" do %>
              <button phx-click="clear_search" class="btn btn-sm btn-ghost">
                Clear all
              </button>
            <% end %>
          </div>
        </form>
        
    <!-- Results Count -->
        <div class="mb-4 text-sm text-base-content/70">
          Found {length(@huddls)} {if length(@huddls) == 1, do: "huddl", else: "huddlz"}
        </div>

        <%= if Enum.empty?(@huddls) do %>
          <div class="text-center py-16 bg-base-200 rounded-lg">
            <svg
              class="mx-auto h-12 w-12 text-base-content/30 mb-4"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M9.172 16.172a4 4 0 015.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
              />
            </svg>
            <p class="text-lg text-base-content/70 mb-2">
              <%= if @keyword_search != "" || @date_filter != "any_day" || @type_filter != "any_type" do %>
                No huddlz found matching your filters. Try adjusting your search criteria.
              <% else %>
                No huddlz found matching your search
              <% end %>
            </p>
            <%= if @keyword_search == "" && @date_filter == "any_day" && @type_filter == "any_type" do %>
              <p class="text-sm text-base-content/50">
                Try adjusting your filters or search terms
              </p>
            <% end %>
          </div>
        <% else %>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            <%= for huddl <- @huddls do %>
              <.link navigate={"/groups/#{huddl.group.slug}/huddlz/#{huddl.id}"} class="block">
                <div class="card bg-base-100 shadow-md hover:shadow-lg transition-shadow">
                  <!-- Event Image -->
                  <%= if huddl.thumbnail_url do %>
                    <figure class="relative h-48">
                      <img
                        src={huddl.thumbnail_url}
                        alt={huddl.title}
                        class="w-full h-full object-cover"
                      />
                      <%= if huddl.event_type in [:virtual, :hybrid] do %>
                        <div class="absolute top-2 right-2 badge badge-primary badge-sm">
                          <svg
                            class="h-3 w-3 mr-1"
                            fill="none"
                            stroke="currentColor"
                            viewBox="0 0 24 24"
                          >
                            <path
                              stroke-linecap="round"
                              stroke-linejoin="round"
                              stroke-width="2"
                              d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1"
                            />
                          </svg>
                          Online link
                        </div>
                      <% end %>
                    </figure>
                  <% else %>
                    <div class="relative h-48 bg-gradient-to-br from-primary/20 to-secondary/20 flex items-center justify-center">
                      <svg
                        class="h-16 w-16 text-base-content/30"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"
                        />
                      </svg>
                      <%= if huddl.event_type in [:virtual, :hybrid] do %>
                        <div class="absolute top-2 right-2 badge badge-primary badge-sm">
                          <svg
                            class="h-3 w-3 mr-1"
                            fill="none"
                            stroke="currentColor"
                            viewBox="0 0 24 24"
                          >
                            <path
                              stroke-linecap="round"
                              stroke-linejoin="round"
                              stroke-width="2"
                              d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1"
                            />
                          </svg>
                          Online link
                        </div>
                      <% end %>
                    </div>
                  <% end %>

                  <div class="card-body">
                    <!-- Date and Time -->
                    <div class="text-sm text-primary font-medium mb-1">
                      {Calendar.strftime(huddl.starts_at, "%a, %b %d · %I:%M %p")}
                    </div>
                    
    <!-- Title -->
                    <h3 class="card-title text-lg line-clamp-2">
                      {huddl.title}
                    </h3>
                    
    <!-- Group Name -->
                    <p class="text-sm text-base-content/70">
                      {huddl.group.name}
                    </p>
                    
    <!-- Location/Type -->
                    <div class="text-sm text-base-content/60 mt-2">
                      <%= case huddl.event_type do %>
                        <% :in_person -> %>
                          <div class="flex items-center gap-1">
                            <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
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
                            <span>
                              {huddl.physical_location}
                              <%= if Map.has_key?(huddl, :distance_miles) &&
                                     huddl.distance_miles &&
                                     !match?(%Ash.NotLoaded{}, huddl.distance_miles) do %>
                                <span class="text-primary">
                                  · {Float.round(huddl.distance_miles, 1)} mi
                                </span>
                              <% end %>
                            </span>
                          </div>
                        <% :virtual -> %>
                          <div class="flex items-center gap-1">
                            <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path
                                stroke-linecap="round"
                                stroke-linejoin="round"
                                stroke-width="2"
                                d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"
                              />
                            </svg>
                            Online event
                          </div>
                        <% :hybrid -> %>
                          <div class="flex items-center gap-1">
                            <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
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
                            <span>
                              {huddl.physical_location} + Online
                              <%= if Map.has_key?(huddl, :distance_miles) &&
                                     huddl.distance_miles &&
                                     !match?(%Ash.NotLoaded{}, huddl.distance_miles) do %>
                                <span class="text-primary">
                                  · {Float.round(huddl.distance_miles, 1)} mi
                                </span>
                              <% end %>
                            </span>
                          </div>
                      <% end %>
                    </div>
                    
    <!-- Attendee Count -->
                    <div class="text-sm text-base-content/60 mt-auto pt-2">
                      {huddl.rsvp_count} {if huddl.rsvp_count == 1, do: "attendee", else: "attendees"}
                    </div>
                  </div>
                </div>
              </.link>
            <% end %>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp date_filter_label("any_day"), do: "Any day"
  defp date_filter_label("starting_soon"), do: "Starting soon"
  defp date_filter_label("today"), do: "Today"
  defp date_filter_label("tomorrow"), do: "Tomorrow"
  defp date_filter_label("this_week"), do: "This Week"
  defp date_filter_label("this_weekend"), do: "This weekend"
  defp date_filter_label("next_week"), do: "Next week"
  defp date_filter_label("this_month"), do: "This Month"
  defp date_filter_label("past_events"), do: "Past events"
  defp date_filter_label(_), do: "Any day"

  defp type_filter_label("any_type"), do: "Any type"
  defp type_filter_label("online"), do: "Virtual"
  defp type_filter_label("in_person"), do: "In person"
  defp type_filter_label(_), do: "Any type"
end
