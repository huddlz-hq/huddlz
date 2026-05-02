defmodule HuddlzWeb.HuddlLive do
  @moduledoc """
  LiveView for searching and filtering huddlz across all groups, with personal
  sections (Hosting, Attending) for authenticated users.
  """
  use HuddlzWeb, :live_view

  alias Huddlz.Communities.Group
  alias HuddlzWeb.Layouts
  require Ash.Query
  require Logger

  @section_limit 6

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_optional}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns[:current_user]

    {:ok,
     socket
     |> assign(:default_location_text, user && user.home_location)
     |> assign(:default_location_lat, user && user.home_latitude)
     |> assign(:default_location_lng, user && user.home_longitude)
     |> assign(:section_limit, @section_limit)
     |> assign_search_defaults()}
  end

  defp assign_search_defaults(socket) do
    assign(socket,
      search_query: nil,
      event_type_filter: nil,
      date_filter: "upcoming",
      distance_miles: 25,
      location_text: socket.assigns.default_location_text,
      location_lat: socket.assigns.default_location_lat,
      location_lng: socket.assigns.default_location_lng,
      location_active:
        not is_nil(socket.assigns.default_location_lat) and
          not is_nil(socket.assigns.default_location_lng),
      scope: :all,
      hosting: [],
      attending: [],
      hosting_total: 0,
      attending_total: 0,
      huddls: [],
      groups: [],
      page_info: %{total_pages: 1, current_page: 1, total_count: 0}
    )
  end

  @impl true
  def handle_params(params, _url, socket) do
    scope = parse_scope(params["yours"])

    if scope != :all and is_nil(socket.assigns.current_user) do
      {:noreply,
       socket
       |> put_flash(:error, "Sign in to view #{sign_in_prompt(scope)}.")
       |> push_navigate(to: ~p"/sign-in")}
    else
      socket =
        socket
        |> assign(:scope, scope)
        |> assign(:page_title, page_title(scope))
        |> assign_filters_from_params(params)
        |> perform_search()

      {:noreply, socket}
    end
  end

  defp assign_filters_from_params(socket, params) do
    {location_text, location_lat, location_lng, location_active} =
      parse_location_params(params, socket)

    socket
    |> assign(:search_query, normalize_string(params["q"]))
    |> assign(:event_type_filter, normalize_event_type(params["event_type"]))
    |> assign(:date_filter, normalize_date_filter(params["date_filter"]))
    |> assign(:distance_miles, parse_distance(params["distance"] || params["distance_miles"]))
    |> assign(:location_text, location_text)
    |> assign(:location_lat, location_lat)
    |> assign(:location_lng, location_lng)
    |> assign(:location_active, location_active)
  end

  defp parse_location_params(params, socket) do
    case {params["lat"], params["lng"]} do
      {lat_str, lng_str} when is_binary(lat_str) and is_binary(lng_str) ->
        with {lat, ""} <- Float.parse(lat_str),
             {lng, ""} <- Float.parse(lng_str) do
          {params["location"], lat, lng, true}
        else
          _ -> {nil, nil, nil, false}
        end

      _ ->
        # Honor the user's home_location pre-fill ONLY when no lat/lng are in the
        # URL — once they explicitly clear, don't auto-resurrect.
        if params["lat"] == nil and params["lng"] == nil and
             not Map.has_key?(params, "cleared") do
          {socket.assigns.default_location_text, socket.assigns.default_location_lat,
           socket.assigns.default_location_lng,
           not is_nil(socket.assigns.default_location_lat) and
             not is_nil(socket.assigns.default_location_lng)}
        else
          {nil, nil, nil, false}
        end
    end
  end

  defp parse_scope("hosting"), do: :hosting
  defp parse_scope("attending"), do: :attending
  defp parse_scope(_), do: :all

  defp normalize_string(nil), do: nil
  defp normalize_string(""), do: nil
  defp normalize_string(s) when is_binary(s), do: s |> String.trim() |> nilify_blank()

  defp nilify_blank(""), do: nil
  defp nilify_blank(s), do: s

  defp normalize_event_type(s) when s in ["in_person", "virtual", "hybrid"], do: s
  defp normalize_event_type(_), do: nil

  defp normalize_date_filter(s) when s in ["upcoming", "this_week", "this_month", "past", "all"],
    do: s

  defp normalize_date_filter(_), do: "upcoming"

  defp parse_distance(nil), do: 25
  defp parse_distance(""), do: 25

  defp parse_distance(val) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} when n in 5..100 -> n
      _ -> 25
    end
  end

  defp parse_distance(val) when is_integer(val) and val in 5..100, do: val
  defp parse_distance(_), do: 25

  defp page_title(:hosting), do: "Huddlz You're Hosting"
  defp page_title(:attending), do: "Huddlz You're Attending"
  defp page_title(:all), do: "Huddlz"

  defp sign_in_prompt(:hosting), do: "huddlz you're hosting"
  defp sign_in_prompt(:attending), do: "huddlz you're attending"

  @impl true
  def handle_event("filter_change", params, socket) do
    {:noreply, push_patch(socket, to: build_path(socket, params))}
  end

  def handle_event("search", params, socket) do
    {:noreply, push_patch(socket, to: build_path(socket, params))}
  end

  def handle_event("clear_filters", _params, socket) do
    send_update(HuddlzWeb.Live.LocationAutocomplete,
      id: "location-autocomplete",
      value: nil,
      latitude: nil,
      longitude: nil
    )

    {:noreply,
     push_patch(socket,
       to: scoped_path(socket.assigns.scope, %{}, override_location_with_cleared: true)
     )}
  end

  def handle_event("change_page", %{"page" => page_str}, socket) do
    page_num = String.to_integer(page_str)
    socket = perform_search(socket, offset: (page_num - 1) * 20)
    {:noreply, socket}
  end

  @impl true
  def handle_info(
        {:location_selected, "location-autocomplete",
         %{display_text: text, latitude: lat, longitude: lng}},
        socket
      ) do
    merged =
      socket
      |> form_params_from_assigns()
      |> Map.merge(%{
        "location" => text,
        "lat" => Float.to_string(lat),
        "lng" => Float.to_string(lng)
      })

    {:noreply, push_patch(socket, to: scoped_path(socket.assigns.scope, merged))}
  end

  def handle_info({:location_cleared, "location-autocomplete"}, socket) do
    if socket.assigns.location_active do
      merged = form_params_from_assigns(socket)

      {:noreply,
       push_patch(socket,
         to: scoped_path(socket.assigns.scope, merged, override_location_with_cleared: true)
       )}
    else
      # Component fires :location_cleared on its own initial mount when its
      # value is nil. Ignoring that no-op so the URL doesn't pick up `cleared=1`
      # spuriously.
      {:noreply, socket}
    end
  end

  defp build_path(socket, params) do
    scoped_path(socket.assigns.scope, params)
  end

  defp scoped_path(scope, form_params, opts \\ []) do
    cleared? = Keyword.get(opts, :override_location_with_cleared, false)

    base = current_filter_params(form_params, cleared?)
    params = put_scope(scope, base)

    case params do
      [] -> ~p"/"
      params -> ~p"/?#{params}"
    end
  end

  defp current_filter_params(form_params, cleared?) do
    non_location_params(form_params)
    |> Kernel.++(location_params(form_params, cleared?))
    |> Enum.reject(&drop_param?/1)
  end

  defp non_location_params(form_params) do
    [
      {"q", form_params["query"]},
      {"event_type", form_params["event_type"]},
      {"date_filter", form_params["date_filter"] || "upcoming"}
    ]
  end

  defp location_params(_form_params, true), do: [{"cleared", "1"}]

  defp location_params(form_params, false) do
    if form_params["lat"] && form_params["lng"] do
      [
        {"location", form_params["location"] || ""},
        {"lat", form_params["lat"]},
        {"lng", form_params["lng"]},
        {"distance", form_params["distance_miles"]}
      ]
    else
      []
    end
  end

  defp drop_param?({_, ""}), do: true
  defp drop_param?({_, nil}), do: true
  defp drop_param?({"date_filter", "upcoming"}), do: true
  defp drop_param?(_), do: false

  defp put_scope(:all, params), do: params
  defp put_scope(scope, params), do: [{"yours", Atom.to_string(scope)} | params]

  defp perform_search(socket, opts \\ []) do
    offset = Keyword.get(opts, :offset, 0)

    base_args = build_search_args(socket)

    main_page =
      run_search(base_args, socket.assigns[:current_user],
        relationship: scope_to_relationship(socket.assigns.scope),
        page: [limit: 20, offset: offset, count: true]
      )

    {huddls, distances} = load_results_with_distances(main_page, socket)
    page_info = extract_page_info(main_page)

    page_info =
      if offset > 0, do: Map.put(page_info, :current_page, div(offset, 20) + 1), else: page_info

    socket
    |> assign(huddls: Enum.zip(huddls, distances))
    |> assign(page_info: page_info)
    |> maybe_load_personal_sections(base_args)
    |> maybe_load_groups(huddls)
  end

  defp build_search_args(socket) do
    {search_lat, search_lng, distance} =
      if socket.assigns.location_active do
        {socket.assigns.location_lat, socket.assigns.location_lng, socket.assigns.distance_miles}
      else
        {nil, nil, nil}
      end

    event_type_atom =
      if socket.assigns.event_type_filter && socket.assigns.event_type_filter != "",
        do: String.to_existing_atom(socket.assigns.event_type_filter),
        else: nil

    %{
      query: socket.assigns.search_query,
      date_filter: String.to_existing_atom(socket.assigns.date_filter),
      event_type: event_type_atom,
      search_latitude: search_lat,
      search_longitude: search_lng,
      distance_miles: distance
    }
  end

  defp scope_to_relationship(:hosting), do: :hosting
  defp scope_to_relationship(:attending), do: :attending
  defp scope_to_relationship(:all), do: nil

  defp run_search(args, actor, opts) do
    relationship = Keyword.get(opts, :relationship)
    page_opts = Keyword.get(opts, :page, [])

    args_with_relationship = Map.put(args, :relationship, relationship)

    Huddlz.Communities.Huddl
    |> Ash.Query.for_read(:search, args_with_relationship, actor: actor)
    |> Ash.read(actor: actor, page: page_opts)
  end

  defp maybe_load_personal_sections(socket, _base_args)
       when is_nil(socket.assigns.current_user) do
    assign(socket, hosting: [], attending: [], hosting_total: 0, attending_total: 0)
  end

  defp maybe_load_personal_sections(socket, _base_args)
       when socket.assigns.scope != :all do
    # On a scoped view, we only render the main grid — sections are hidden.
    assign(socket, hosting: [], attending: [], hosting_total: 0, attending_total: 0)
  end

  defp maybe_load_personal_sections(socket, base_args) do
    user = socket.assigns.current_user

    {hosting, hosting_total} = load_section(base_args, user, :hosting)
    {attending, attending_total} = load_section(base_args, user, :attending)

    socket
    |> assign(:hosting, hosting)
    |> assign(:hosting_total, hosting_total)
    |> assign(:attending, attending)
    |> assign(:attending_total, attending_total)
  end

  defp load_section(base_args, user, relationship) do
    page =
      run_search(base_args, user,
        relationship: relationship,
        page: [limit: @section_limit, offset: 0, count: true]
      )

    case page do
      {:ok, %{results: results, count: count}} ->
        loaded =
          Ash.load!(
            results,
            [:status, :rsvp_count, :visible_virtual_link, :display_image_url, :group],
            actor: user
          )

        {loaded, count || length(loaded)}

      _ ->
        {[], 0}
    end
  end

  defp maybe_load_groups(socket, [_ | _]), do: assign(socket, :groups, [])

  defp maybe_load_groups(socket, []) do
    has_filters =
      socket.assigns.search_query != nil or
        socket.assigns.event_type_filter != nil or
        socket.assigns.date_filter != "upcoming" or
        socket.assigns.location_active

    if has_filters or socket.assigns.scope != :all do
      assign(socket, :groups, [])
    else
      assign(socket, :groups, list_public_groups())
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

  defp load_results_with_distances({:error, reason}, _socket) do
    Logger.warning("Huddl search failed: #{inspect(reason)}")
    {[], []}
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

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div>
        <h1 :if={@scope != :all} class="font-display text-2xl tracking-tight text-glow mb-4">
          {page_title(@scope)}
        </h1>

        <div class="mb-8">
          <form phx-change="filter_change" phx-submit="search">
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
              <div class="flex-grow min-w-[200px]">
                <.live_component
                  module={HuddlzWeb.Live.LocationAutocomplete}
                  id="location-autocomplete"
                  field_name="location"
                  value={@location_text}
                  latitude={@location_lat}
                  longitude={@location_lng}
                  label="Location"
                  label_class="sr-only"
                  placeholder="City, State"
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

          <%= if any_filter_active?(assigns) do %>
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
                <span
                  data-testid="location-badge"
                  class="text-xs px-2.5 py-1 bg-primary/10 text-primary font-medium inline-flex items-center gap-1"
                >
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

        <%= if @scope == :all and @current_user do %>
          <.personal_section
            :if={@hosting_total > 0}
            title="Hosting"
            count={@hosting_total}
            huddls={@hosting}
            limit={@section_limit}
            view_all_path={view_all_path(:hosting, assigns)}
          />
          <.personal_section
            :if={@attending_total > 0}
            title="Attending"
            count={@attending_total}
            huddls={@attending}
            limit={@section_limit}
            view_all_path={view_all_path(:attending, assigns)}
          />
        <% end %>

        <div class="w-full">
          <%= if Enum.empty?(@huddls) do %>
            <%= if any_filter_active?(assigns) or @scope != :all do %>
              <div class="border border-dashed border-base-300 p-12 text-center">
                <p class="text-lg text-base-content/50">{empty_message(assigns)}</p>
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
            <h2
              :if={show_main_heading?(assigns)}
              class="font-display text-lg tracking-tight text-glow flex items-baseline gap-3 mb-4"
            >
              <span class="mono-label text-primary/70">// {main_heading(@scope)}</span>
              <span class="text-sm font-body font-normal text-base-content/40">
                ({@page_info.total_count})
              </span>
            </h2>
            <div :if={!show_main_heading?(assigns)} class="mb-4 text-sm text-base-content/40">
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

        <div :if={@scope != :all} class="mt-6">
          <.link navigate={~p"/"} class="text-sm text-primary hover:underline font-medium">
            ← All huddlz
          </.link>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :title, :string, required: true
  attr :count, :integer, required: true
  attr :huddls, :list, required: true
  attr :limit, :integer, required: true
  attr :view_all_path, :string, required: true

  defp personal_section(assigns) do
    ~H"""
    <div class="mt-10">
      <div class="flex items-baseline justify-between gap-2">
        <h2 class="font-display text-lg tracking-tight text-glow flex items-baseline gap-3">
          <span class="mono-label text-primary/70">// {@title}</span>
          <span class="text-sm font-body font-normal text-base-content/40">
            ({@count})
          </span>
        </h2>
        <.link
          :if={@count > @limit}
          navigate={@view_all_path}
          class="text-xs text-primary hover:underline font-medium tracking-wide uppercase"
        >
          View all →
        </.link>
      </div>

      <div class="grid gap-6 sm:grid-cols-2 lg:grid-cols-3 mt-4">
        <%= for huddl <- @huddls do %>
          <.huddl_card huddl={huddl} show_group={true} />
        <% end %>
      </div>
    </div>
    """
  end

  defp view_all_path(scope, assigns) do
    cleared? = location_explicitly_cleared?(assigns)
    params = current_filter_params(form_params_from_assigns(assigns), cleared?)
    params = put_scope(scope, params)

    case params do
      [] -> ~p"/"
      params -> ~p"/?#{params}"
    end
  end

  defp location_explicitly_cleared?(assigns) do
    not assigns.location_active and
      not is_nil(assigns.default_location_lat) and
      not is_nil(assigns.default_location_lng)
  end

  defp form_params_from_assigns(%Phoenix.LiveView.Socket{assigns: assigns}),
    do: form_params_from_assigns(assigns)

  defp form_params_from_assigns(assigns) do
    base = %{
      "query" => assigns.search_query,
      "event_type" => assigns.event_type_filter,
      "date_filter" => assigns.date_filter
    }

    if assigns.location_active do
      Map.merge(base, %{
        "location" => assigns.location_text,
        "lat" => Float.to_string(assigns.location_lat),
        "lng" => Float.to_string(assigns.location_lng),
        "distance_miles" => Integer.to_string(assigns.distance_miles)
      })
    else
      base
    end
  end

  defp any_filter_active?(assigns) do
    not is_nil(assigns.search_query) or not is_nil(assigns.event_type_filter) or
      assigns.date_filter != "upcoming" or assigns.location_active
  end

  defp show_main_heading?(%{
         scope: scope,
         current_user: user,
         hosting_total: h,
         attending_total: a
       })
       when scope == :all and not is_nil(user) and (h > 0 or a > 0),
       do: true

  defp show_main_heading?(_), do: false

  defp main_heading(:hosting), do: "Hosting"
  defp main_heading(:attending), do: "Attending"
  defp main_heading(:all), do: "All Huddlz"

  defp empty_message(%{scope: :hosting}), do: "You aren't hosting any huddlz that match."
  defp empty_message(%{scope: :attending}), do: "You aren't attending any huddlz that match."

  defp empty_message(%{scope: :all}),
    do: "No huddlz found matching your filters. Try adjusting your search criteria."

  defp humanize_filter(filter) do
    filter
    |> to_string()
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map_join(" ", &String.capitalize/1)
  end
end
