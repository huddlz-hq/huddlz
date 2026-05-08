defmodule HuddlzWeb.HuddlLive do
  @moduledoc """
  LiveView at `/discover`. Renders combined search across huddlz and groups —
  the active resource type is selected by the `?scope=huddlz|groups` URL param
  (defaults to `huddlz`). The legacy `?yours=hosting|attending` param scopes
  the huddl results to the actor's relationship; it is huddl-only and ignored
  under `scope=groups`. Personal sections (Hosting, Attending) live on
  `MeLive` at `/me`; this view is shared by anonymous and signed-in users.
  """
  use HuddlzWeb, :live_view

  alias Huddlz.Communities
  alias Huddlz.Communities.Group
  alias HuddlzWeb.Layouts
  require Ash.Query
  require Logger

  @huddl_card_loads [:status, :rsvp_count, :visible_virtual_link, :display_image_url, :group]
  @page_size 20

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_optional}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns[:current_user]

    {:ok,
     socket
     |> assign(:default_location_text, user && user.home_location)
     |> assign(:default_location_lat, user && user.home_latitude)
     |> assign(:default_location_lng, user && user.home_longitude)
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
      scope: :huddlz,
      yours: :all,
      sort: :soonest,
      huddls: [],
      groups: [],
      page_info: %{total_pages: 1, current_page: 1, total_count: 0}
    )
  end

  @impl true
  def handle_params(params, _url, socket) do
    scope = parse_scope(params["scope"])
    yours = parse_yours(params["yours"], scope)

    if yours != :all and is_nil(socket.assigns.current_user) do
      {:noreply,
       socket
       |> put_flash(:error, "Sign in to view #{sign_in_prompt(yours)}.")
       |> push_navigate(to: ~p"/sign-in")}
    else
      page = parse_page(params["page"])

      socket =
        socket
        |> assign(:scope, scope)
        |> assign(:yours, yours)
        |> assign(:page_title, page_title(scope, yours))
        |> assign_filters_from_params(params)
        |> perform_search(offset: (page - 1) * @page_size)

      total_pages = socket.assigns.page_info.total_pages

      if page > total_pages do
        # Out-of-range page: clamp by patching to the last valid page so the URL
        # reflects what the user actually sees.
        cleared? = location_explicitly_cleared?(socket.assigns)

        path =
          scoped_path(scope, yours, form_params_from_assigns(socket),
            override_location_with_cleared: cleared?,
            page: total_pages
          )

        {:noreply, push_patch(socket, to: path)}
      else
        {:noreply, socket}
      end
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
    |> assign(:sort, parse_sort(params["sort"]))
    |> assign(:location_text, location_text)
    |> assign(:location_lat, location_lat)
    |> assign(:location_lng, location_lng)
    |> assign(:location_active, location_active)
  end

  defp parse_sort("newest"), do: :newest
  defp parse_sort(:newest), do: :newest
  defp parse_sort(_), do: :soonest

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

  defp parse_scope("groups"), do: :groups
  defp parse_scope(_), do: :huddlz

  # `?yours=` is huddl-only — ignore under scope=groups
  defp parse_yours(_, :groups), do: :all
  defp parse_yours("hosting", _), do: :hosting
  defp parse_yours("attending", _), do: :attending
  defp parse_yours(_, _), do: :all

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

  defp parse_page(nil), do: 1
  defp parse_page(""), do: 1

  defp parse_page(val) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} when n >= 1 -> n
      _ -> 1
    end
  end

  defp parse_page(val) when is_integer(val) and val >= 1, do: val
  defp parse_page(_), do: 1

  defp page_title(:groups, _), do: "groups"
  defp page_title(:huddlz, :hosting), do: "huddlz you're hosting"
  defp page_title(:huddlz, :attending), do: "huddlz you're attending"
  defp page_title(:huddlz, :all), do: "huddlz"

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
       to:
         scoped_path(socket.assigns.scope, socket.assigns.yours, %{},
           override_location_with_cleared: true
         )
     )}
  end

  def handle_event("change_page", %{"page" => page_str}, socket) do
    page = parse_page(page_str)
    cleared? = location_explicitly_cleared?(socket.assigns)

    path =
      scoped_path(socket.assigns.scope, socket.assigns.yours, form_params_from_assigns(socket),
        override_location_with_cleared: cleared?,
        page: page
      )

    {:noreply, push_patch(socket, to: path)}
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

    {:noreply,
     push_patch(socket, to: scoped_path(socket.assigns.scope, socket.assigns.yours, merged))}
  end

  def handle_info({:location_cleared, "location-autocomplete"}, socket) do
    if socket.assigns.location_active do
      merged = form_params_from_assigns(socket)

      {:noreply,
       push_patch(socket,
         to:
           scoped_path(socket.assigns.scope, socket.assigns.yours, merged,
             override_location_with_cleared: true
           )
       )}
    else
      # No-op when there was nothing to clear, so the URL doesn't pick up
      # `cleared=1` spuriously.
      {:noreply, socket}
    end
  end

  defp build_path(socket, params) do
    # Form events (phx-change/phx-submit) only carry the inputs that exist on
    # that form. Filters now live on a separate panel from the search input,
    # so any submission would otherwise clobber filters not present in the
    # event params. Merge form_params over the current assigns-derived state
    # so missing keys preserve their current value.
    merged = Map.merge(form_params_from_assigns(socket), params)

    scoped_path(
      socket.assigns.scope,
      socket.assigns.yours,
      merge_active_location(socket, merged)
    )
  end

  # The autocomplete component only emits a hidden `location` text input on the
  # form; lat/lng live in component state and reach the parent via :location_selected.
  # Plain form events (typing search, changing date, etc.) therefore don't carry
  # lat/lng — merge them in from socket assigns so the URL doesn't silently drop
  # an active location filter.
  defp merge_active_location(%{assigns: %{location_active: false}}, params), do: params

  defp merge_active_location(%{assigns: assigns}, params) do
    if params["lat"] && params["lng"] do
      params
    else
      Map.merge(params, %{
        "location" => params["location"] || assigns.location_text,
        "lat" => Float.to_string(assigns.location_lat),
        "lng" => Float.to_string(assigns.location_lng)
      })
    end
  end

  defp scoped_path(scope, yours, form_params, opts \\ []) do
    cleared? = Keyword.get(opts, :override_location_with_cleared, false)
    page = Keyword.get(opts, :page, 1)

    base = current_filter_params(form_params, cleared?) ++ page_params(page)

    params =
      base
      |> put_yours(yours)
      |> put_scope(scope)

    case params do
      [] -> ~p"/discover"
      params -> ~p"/discover?#{params}"
    end
  end

  defp page_params(page) when is_integer(page) and page > 1,
    do: [{"page", Integer.to_string(page)}]

  defp page_params(_), do: []

  defp current_filter_params(form_params, cleared?) do
    non_location_params(form_params)
    |> Kernel.++(location_params(form_params, cleared?))
    |> Enum.reject(&drop_param?/1)
  end

  defp non_location_params(form_params) do
    [
      {"q", form_params["query"]},
      {"event_type", form_params["event_type"]},
      {"date_filter", form_params["date_filter"] || "upcoming"},
      {"sort", form_params["sort"] || "soonest"}
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
  defp drop_param?({"sort", "soonest"}), do: true
  defp drop_param?(_), do: false

  defp put_yours(params, :all), do: params
  defp put_yours(params, yours), do: [{"yours", Atom.to_string(yours)} | params]

  defp put_scope(params, :huddlz), do: params
  defp put_scope(params, :groups), do: [{"scope", "groups"} | params]

  defp perform_search(%{assigns: %{scope: :huddlz}} = socket, opts) do
    offset = Keyword.get(opts, :offset, 0)

    base_args = build_search_args(socket)

    main_page =
      run_search(base_args, socket.assigns[:current_user],
        relationship: yours_to_relationship(socket.assigns.yours),
        page: [limit: @page_size, offset: offset, count: true]
      )

    {huddls, distances} = load_results_with_distances(main_page, socket)
    page_info = extract_page_info(main_page)

    page_info =
      if offset > 0,
        do: Map.put(page_info, :current_page, div(offset, @page_size) + 1),
        else: page_info

    socket
    |> assign(huddls: Enum.zip(huddls, distances))
    |> assign(groups: [])
    |> assign(page_info: page_info)
  end

  defp perform_search(%{assigns: %{scope: :groups}} = socket, opts) do
    offset = Keyword.get(opts, :offset, 0)
    page = div(offset, @page_size) + 1
    actor = socket.assigns[:current_user]

    {groups, total} = list_groups(socket.assigns.search_query, page, actor)

    page_info =
      if total > 0 do
        %{
          total_pages: ceil(total / @page_size),
          current_page: page,
          total_count: total
        }
      else
        %{total_pages: 1, current_page: 1, total_count: 0}
      end

    socket
    |> assign(huddls: [])
    |> assign(groups: groups)
    |> assign(page_info: page_info)
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
      distance_miles: distance,
      sort: socket.assigns.sort
    }
  end

  defp yours_to_relationship(:hosting), do: :hosting
  defp yours_to_relationship(:attending), do: :attending
  defp yours_to_relationship(:all), do: nil

  defp run_search(args, actor, opts) do
    Communities.search_huddlz(
      args.query,
      args.date_filter,
      args.event_type,
      args.search_latitude,
      args.search_longitude,
      args.distance_miles,
      Keyword.get(opts, :relationship),
      args.sort,
      actor: actor,
      page: Keyword.get(opts, :page, [])
    )
  end

  # Public-only directory: anonymous users can only see public groups, and a
  # member's private groups already surface in /groups under their personal
  # sections, so re-listing them here would just duplicate.
  defp list_groups(query, page, actor) do
    ash_query =
      Group
      |> Ash.Query.for_read(:search, %{query: query}, actor: actor)
      |> Ash.Query.filter(is_public == true)

    total =
      case Ash.count(ash_query, actor: actor) do
        {:ok, n} ->
          n

        {:error, reason} ->
          Logger.warning("HuddlLive group count failed: #{inspect(reason)}")
          0
      end

    paginated =
      ash_query
      |> Ash.Query.load(:current_image_url)
      |> Ash.Query.limit(@page_size)
      |> Ash.Query.offset((page - 1) * @page_size)

    groups =
      case Ash.read(paginated, actor: actor) do
        {:ok, gs} ->
          gs

        {:error, reason} ->
          Logger.warning("HuddlLive group read failed: #{inspect(reason)}")
          []
      end

    {groups, total}
  end

  defp load_results_with_distances({:ok, %{results: results}}, socket) do
    loaded = load_huddl_cards(results, socket.assigns[:current_user])

    dists = compute_distances(loaded, socket)
    {loaded, dists}
  end

  defp load_results_with_distances({:error, reason}, _socket) do
    Logger.warning("Huddl search failed: #{inspect(reason)}")
    {[], []}
  end

  defp load_results_with_distances(_, _socket), do: {[], []}

  defp load_huddl_cards(results, actor) do
    Ash.load!(results, @huddl_card_loads, actor: actor)
  end

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

  defp show_filter_panel(js \\ %JS{}) do
    js
    |> JS.show(to: "#filter-panel")
    |> JS.show(
      to: "#filter-panel-bg",
      time: 200,
      transition: {"transition-opacity ease-out duration-200", "opacity-0", "opacity-100"}
    )
    |> JS.show(
      to: "#filter-panel-container",
      time: 200,
      transition:
        {"transition-transform ease-out duration-200",
         "translate-y-full lg:translate-y-0 lg:translate-x-full",
         "translate-y-0 lg:translate-x-0"}
    )
    |> JS.add_class("overflow-hidden", to: "body")
    |> JS.focus_first(to: "#filter-panel-container")
  end

  defp hide_filter_panel(js \\ %JS{}) do
    js
    |> JS.hide(
      to: "#filter-panel-bg",
      time: 200,
      transition: {"transition-opacity ease-in duration-200", "opacity-100", "opacity-0"}
    )
    |> JS.hide(
      to: "#filter-panel-container",
      time: 200,
      transition:
        {"transition-transform ease-in duration-200", "translate-y-0 lg:translate-x-0",
         "translate-y-full lg:translate-y-0 lg:translate-x-full"}
    )
    |> JS.hide(to: "#filter-panel", transition: {"block", "block", "hidden"})
    |> JS.remove_class("overflow-hidden", to: "body")
  end

  defp filter_url(overrides, assigns) do
    params = Map.merge(form_params_from_assigns(assigns), overrides)
    scoped_path(assigns.scope, assigns.yours, params)
  end

  defp date_toggle_url(target, assigns) do
    new_value = if assigns.date_filter == target, do: "upcoming", else: target
    filter_url(%{"date_filter" => new_value}, assigns)
  end

  defp format_toggle_url(target, assigns) do
    new_value = if assigns.event_type_filter == target, do: nil, else: target
    filter_url(%{"event_type" => new_value}, assigns)
  end

  defp sort_toggle_url(target, assigns) do
    new_value = if Atom.to_string(assigns.sort) == target, do: "soonest", else: target
    filter_url(%{"sort" => new_value}, assigns)
  end

  defp distance_change_url(target, assigns) do
    filter_url(%{"distance_miles" => target}, assigns)
  end

  defp toggle_class(active?) do
    base =
      "inline-flex items-center justify-center min-h-9 px-3 text-sm font-medium border transition-colors"

    if active? do
      base <> " border-primary bg-primary/15 text-primary"
    else
      base <> " border-base-300 hover:border-primary/50 text-base-content"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} search_query={@search_query}>
      <div>
        <div class="mb-6">
          <h1 class="font-display text-3xl md:text-4xl tracking-tight text-glow">
            {results_heading(@scope, @yours, @search_query)}
          </h1>
          <p
            :if={results_subtitle(@scope, @yours, @search_query, @location_text)}
            class="mt-2 text-base-content/60"
          >
            {results_subtitle(@scope, @yours, @search_query, @location_text)}
          </p>
        </div>

        <div class="flex flex-wrap items-center gap-2 mb-6">
          <.page_tab patch={chip_path(:huddlz, assigns)} active={@scope == :huddlz}>
            Huddlz
          </.page_tab>
          <.page_tab patch={chip_path(:groups, assigns)} active={@scope == :groups}>
            Groups
          </.page_tab>
        </div>

        <div class="mb-8">
          <form id="huddl-search-form" phx-change="filter_change" phx-submit="search">
            <div class="flex flex-wrap items-stretch gap-2">
              <div class="flex-grow min-w-[200px]">
                <label for="search-query" class="sr-only">{search_label(@scope)}</label>
                <input
                  id="search-query"
                  type="text"
                  name="query"
                  value={@search_query}
                  placeholder={search_placeholder(@scope)}
                  phx-debounce="300"
                  class="w-full h-12 pl-0 pr-4 border-0 border-b border-base-300 bg-transparent text-base focus:outline-none focus:ring-0 focus:border-primary transition-colors placeholder:text-base-content/30"
                />
              </div>
              <.button variant="primary" type="submit" class="h-12 active:scale-[0.98]">
                Search
              </.button>
              <%= if @scope == :huddlz do %>
                <button
                  type="button"
                  phx-click={show_filter_panel()}
                  aria-controls="filter-panel"
                  class="h-12 px-4 inline-flex items-center gap-2 border border-base-300 hover:border-primary/50 text-base-content text-sm font-medium transition-colors active:scale-[0.98]"
                >
                  <.icon name="hero-adjustments-horizontal" class="w-4 h-4" /> Filters
                </button>
              <% end %>
            </div>
          </form>

          <%= if @scope == :huddlz and any_filter_active?(assigns) do %>
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
              <%= if @sort != :soonest do %>
                <span class="text-xs px-2.5 py-1 bg-secondary/10 text-secondary font-medium inline-flex items-center">
                  Sort: {humanize_filter(@sort)}
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
              <.button variant="ghost" size="sm" type="button" phx-click="clear_filters">
                Clear all
              </.button>
            </div>
          <% end %>
        </div>

        <div :if={@scope == :huddlz} class="w-full">
          <div class="mono-label text-primary/70 mb-3">Huddlz</div>
          <%= if Enum.empty?(@huddls) do %>
            <.surface_panel variant="dashed" class="p-12 text-center">
              <p class="text-lg text-base-content/50">{empty_message(assigns)}</p>
            </.surface_panel>
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

        <div :if={@scope == :groups} class="w-full">
          <div class="mono-label text-primary/70 mb-3">Groups</div>
          <%= if @groups == [] do %>
            <.surface_panel variant="dashed" class="p-12 text-center">
              <p class="text-lg text-base-content/50">{empty_message(assigns)}</p>
            </.surface_panel>
          <% else %>
            <div class="mb-4 text-sm text-base-content/40">
              Found {@page_info.total_count} {if @page_info.total_count == 1,
                do: "group",
                else: "groups"}
            </div>
            <div class="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
              <%= for group <- @groups do %>
                <.group_card group={group} />
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

        <div :if={@yours != :all} class="mt-6">
          <.link
            patch={view_all_path(:all, assigns)}
            class="text-sm text-primary hover:underline font-medium"
          >
            ← All huddlz
          </.link>
        </div>

        <div
          :if={@scope == :huddlz}
          id="filter-panel"
          class="hidden fixed inset-0 z-50"
          phx-remove={hide_filter_panel()}
          data-cancel={JS.exec("phx-remove", to: "#filter-panel")}
        >
          <div
            id="filter-panel-bg"
            class="fixed inset-0 bg-black/60"
            phx-click={JS.exec("data-cancel", to: "#filter-panel")}
            aria-hidden="true"
          />
          <.focus_wrap
            id="filter-panel-container"
            phx-window-keydown={JS.exec("data-cancel", to: "#filter-panel")}
            phx-key="escape"
            class="fixed bottom-0 inset-x-0 lg:bottom-auto lg:top-0 lg:right-0 lg:left-auto w-full lg:w-[430px] max-h-[76vh] lg:max-h-none lg:h-screen border-t lg:border-t-0 lg:border-l border-base-300 bg-base-100 flex flex-col"
            role="dialog"
            aria-modal="true"
            aria-labelledby="filter-panel-title"
          >
            <header class="flex items-center justify-between px-5 py-4 border-b border-base-300 flex-shrink-0">
              <h2 id="filter-panel-title" class="font-display text-2xl tracking-tight text-glow">
                Filters
              </h2>
              <button
                type="button"
                phx-click={JS.exec("data-cancel", to: "#filter-panel")}
                aria-label="Close filters"
                class="text-base-content/40 hover:text-base-content transition-colors p-1"
              >
                <.icon name="hero-x-mark" class="w-5 h-5" />
              </button>
            </header>

            <div class="flex-1 overflow-y-auto px-5 py-4 space-y-6">
              <section>
                <h3 class="mono-label text-base-content/60 mb-3">Date</h3>
                <div class="flex flex-wrap gap-2">
                  <.link
                    patch={date_toggle_url("upcoming", assigns)}
                    class={toggle_class(@date_filter == "upcoming")}
                  >
                    Upcoming
                  </.link>
                  <.link
                    patch={date_toggle_url("this_week", assigns)}
                    class={toggle_class(@date_filter == "this_week")}
                  >
                    This week
                  </.link>
                  <.link
                    patch={date_toggle_url("this_month", assigns)}
                    class={toggle_class(@date_filter == "this_month")}
                  >
                    This month
                  </.link>
                  <.link
                    patch={date_toggle_url("all", assigns)}
                    class={toggle_class(@date_filter == "all")}
                  >
                    All
                  </.link>
                </div>
              </section>

              <section>
                <h3 class="mono-label text-base-content/60 mb-3">Format</h3>
                <div class="flex flex-wrap gap-2">
                  <.link
                    patch={format_toggle_url("in_person", assigns)}
                    class={toggle_class(@event_type_filter == "in_person")}
                  >
                    In person
                  </.link>
                  <.link
                    patch={format_toggle_url("virtual", assigns)}
                    class={toggle_class(@event_type_filter == "virtual")}
                  >
                    Virtual
                  </.link>
                  <.link
                    patch={format_toggle_url("hybrid", assigns)}
                    class={toggle_class(@event_type_filter == "hybrid")}
                  >
                    Hybrid
                  </.link>
                </div>
              </section>

              <section>
                <h3 class="mono-label text-base-content/60 mb-3">Location</h3>
                <div class="space-y-3">
                  <.live_component
                    module={HuddlzWeb.Live.LocationAutocomplete}
                    id="location-autocomplete"
                    field_name="location"
                    value={@location_text}
                    latitude={@location_lat}
                    longitude={@location_lng}
                    label="City"
                    label_class="mono-label text-base-content/60 mb-2 block"
                    placeholder="City, State"
                  />
                  <div :if={@location_active}>
                    <span class="mono-label text-base-content/60 mb-2 block">Distance</span>
                    <div class="flex flex-wrap gap-2">
                      <%= for miles <- [10, 25, 50, 100] do %>
                        <.link
                          patch={distance_change_url(Integer.to_string(miles), assigns)}
                          class={toggle_class(@distance_miles == miles)}
                        >
                          {miles} mi
                        </.link>
                      <% end %>
                    </div>
                  </div>
                </div>
              </section>

              <section>
                <h3 class="mono-label text-base-content/60 mb-3">Sort</h3>
                <div class="flex flex-wrap gap-2">
                  <.link
                    patch={sort_toggle_url("soonest", assigns)}
                    class={toggle_class(@sort == :soonest)}
                  >
                    Soonest
                  </.link>
                  <.link
                    patch={sort_toggle_url("newest", assigns)}
                    class={toggle_class(@sort == :newest)}
                  >
                    Newest
                  </.link>
                </div>
              </section>
            </div>

            <footer class="flex items-center justify-end px-5 py-4 border-t border-base-300 flex-shrink-0">
              <.button variant="ghost" size="sm" type="button" phx-click="clear_filters">
                Reset
              </.button>
            </footer>
          </.focus_wrap>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp results_heading(_, :hosting, _), do: "huddlz you're hosting"
  defp results_heading(_, :attending, _), do: "huddlz you're attending"
  defp results_heading(_, _, q) when is_binary(q) and q != "", do: "Results for #{q}"
  defp results_heading(:groups, _, _), do: "Discover groups"
  defp results_heading(:huddlz, _, _), do: "Discover huddlz"

  defp results_subtitle(_, yours, _, _) when yours in [:hosting, :attending], do: nil

  defp results_subtitle(:huddlz, _, q, location) do
    base =
      if is_binary(q) and q != "",
        do: "Huddlz matching your search",
        else: "Real-life gatherings"

    location_suffix = if location, do: " near #{location}", else: ""
    base <> location_suffix <> "."
  end

  defp results_subtitle(:groups, _, q, _location) do
    if is_binary(q) and q != "" do
      "Groups matching your search."
    else
      "Communities organizing huddlz."
    end
  end

  defp search_placeholder(:groups), do: "Search groups"
  defp search_placeholder(_), do: "Find your huddl"

  defp search_label(:groups), do: "Search groups"
  defp search_label(_), do: "Search huddlz"

  defp chip_path(target_scope, assigns) do
    cleared? = location_explicitly_cleared?(assigns)

    target_yours = if target_scope == :groups, do: :all, else: assigns.yours

    params =
      assigns
      |> form_params_from_assigns()
      |> current_filter_params(cleared?)
      |> put_yours(target_yours)
      |> put_scope(target_scope)

    case params do
      [] -> ~p"/discover"
      params -> ~p"/discover?#{params}"
    end
  end

  defp view_all_path(yours, assigns) do
    cleared? = location_explicitly_cleared?(assigns)

    params =
      assigns
      |> form_params_from_assigns()
      |> current_filter_params(cleared?)
      |> put_yours(yours)
      |> put_scope(assigns.scope)

    case params do
      [] -> ~p"/discover"
      params -> ~p"/discover?#{params}"
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
      "date_filter" => assigns.date_filter,
      "sort" => Atom.to_string(assigns.sort)
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
      assigns.date_filter != "upcoming" or assigns.location_active or assigns.sort != :soonest
  end

  defp empty_message(%{scope: :groups}),
    do: "No groups match this search. Try Huddlz or change your filters."

  defp empty_message(%{yours: :hosting}), do: "You aren't hosting any huddlz that match."
  defp empty_message(%{yours: :attending}), do: "You aren't attending any huddlz that match."

  defp empty_message(%{scope: :huddlz} = assigns) do
    if any_filter_active?(assigns) do
      "No huddlz match this search. Try Groups or change your filters."
    else
      "No upcoming huddlz right now."
    end
  end

  defp humanize_filter(filter) do
    filter
    |> to_string()
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map_join(" ", &String.capitalize/1)
  end
end
