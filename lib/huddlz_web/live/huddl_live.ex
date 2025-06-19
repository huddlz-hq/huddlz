defmodule HuddlzWeb.HuddlLive do
  use HuddlzWeb, :live_view

  alias Huddlz.Communities
  alias HuddlzWeb.Layouts
  require Ash.Query

  # Authentication is optional - show cards to all but require auth for joining
  on_mount {HuddlzWeb.LiveUserAuth, :live_user_optional}

  def mount(_params, _session, socket) do
    # Always load upcoming huddls to avoid showing past events
    upcoming_huddls =
      Communities.get_upcoming!(actor: socket.assigns[:current_user])
      |> Ash.load!([:status, :visible_virtual_link, :group])

    {:ok,
     assign(socket,
       huddls: upcoming_huddls,
       search_query: nil,
       event_type_filter: nil,
       date_filter: "upcoming",
       sort_by: "date_asc"
     )}
  end

  def handle_event("search", params, socket) do
    query = params["query"]
    event_type = params["event_type"]
    date_filter = params["date_filter"] || "upcoming"
    sort_by = params["sort_by"] || "date_asc"

    socket =
      socket
      |> assign(search_query: query)
      |> assign(event_type_filter: event_type)
      |> assign(date_filter: date_filter)
      |> assign(sort_by: sort_by)
      |> apply_filters()

    {:noreply, socket}
  end

  def handle_event("clear_filters", _params, socket) do
    socket =
      socket
      |> assign(search_query: nil)
      |> assign(event_type_filter: nil)
      |> assign(date_filter: "upcoming")
      |> assign(sort_by: "date_asc")
      |> apply_filters()

    {:noreply, socket}
  end

  defp apply_filters(socket) do
    huddls = get_filtered_huddls(socket)
    assign(socket, huddls: huddls)
  end

  defp get_filtered_huddls(socket) do
    %{
      search_query: query,
      event_type_filter: event_type,
      date_filter: date_filter,
      sort_by: sort_by,
      current_user: current_user
    } = socket.assigns

    # Use the appropriate read action based on date filter
    base_huddls =
      case date_filter do
        "past" ->
          Huddlz.Communities.Huddl
          |> Ash.Query.for_read(:past, %{}, actor: current_user)
          |> Ash.read!(actor: current_user)

        _ ->
          current_user
          |> get_base_huddls(query)
          |> apply_date_filter(date_filter)
      end

    base_huddls
    |> apply_event_type_filter(event_type)
    |> apply_sorting(sort_by)
    |> Ash.load!([:status, :visible_virtual_link, :group], actor: current_user)
  end

  defp get_base_huddls(current_user, query) when is_binary(query) and query != "" do
    Communities.search_huddlz!(query, actor: current_user)
  end

  defp get_base_huddls(current_user, _query) do
    Huddlz.Communities.Huddl
    |> Ash.read!(actor: current_user)
  end

  defp apply_date_filter(huddls, "upcoming") do
    Enum.filter(huddls, fn huddl ->
      DateTime.compare(huddl.starts_at, DateTime.utc_now()) == :gt
    end)
  end

  defp apply_date_filter(huddls, "this_week") do
    now = DateTime.utc_now()
    week_end = DateTime.add(now, 7 * 24 * 60 * 60, :second)

    Enum.filter(huddls, fn huddl ->
      DateTime.compare(huddl.starts_at, now) == :gt &&
        DateTime.compare(huddl.starts_at, week_end) != :gt
    end)
  end

  defp apply_date_filter(huddls, "this_month") do
    now = DateTime.utc_now()
    month_end = DateTime.add(now, 30 * 24 * 60 * 60, :second)

    Enum.filter(huddls, fn huddl ->
      DateTime.compare(huddl.starts_at, now) == :gt &&
        DateTime.compare(huddl.starts_at, month_end) != :gt
    end)
  end

  defp apply_date_filter(huddls, "past") do
    Enum.filter(huddls, fn huddl ->
      DateTime.compare(huddl.starts_at, DateTime.utc_now()) == :lt
    end)
  end

  defp apply_date_filter(huddls, _), do: huddls

  defp apply_event_type_filter(huddls, event_type)
       when is_binary(event_type) and event_type != "" do
    Enum.filter(huddls, fn huddl ->
      to_string(huddl.event_type) == event_type
    end)
  end

  defp apply_event_type_filter(huddls, _), do: huddls

  defp apply_sorting(huddls, "recent") do
    Enum.sort_by(huddls, & &1.inserted_at, {:desc, DateTime})
  end

  defp apply_sorting(huddls, _) do
    # Default to date_asc
    Enum.sort_by(huddls, & &1.starts_at, {:asc, DateTime})
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
                  <option value="past" selected={@date_filter == "past"}>
                    Past Events
                  </option>
                </select>
              </div>
              
    <!-- Sort By -->
              <div class="form-control">
                <label for="sort-by" class="label">
                  <span class="label-text">Sort By</span>
                </label>
                <select id="sort-by" name="sort_by" class="select select-bordered">
                  <option value="date_asc" selected={@sort_by == "date_asc"}>
                    Date (Earliest First)
                  </option>
                  <option value="recent" selected={@sort_by == "recent"}>
                    Recently Added
                  </option>
                </select>
              </div>
            </div>
          </form>
          
    <!-- Active Filters Display -->
          <%= if @search_query || @event_type_filter || @date_filter != "upcoming" || @sort_by != "date_asc" do %>
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
              <%= if @sort_by != "date_asc" do %>
                <span class="badge badge-primary">Sort: {humanize_filter(@sort_by)}</span>
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
end
