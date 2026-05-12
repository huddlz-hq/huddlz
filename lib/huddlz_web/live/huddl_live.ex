defmodule HuddlzWeb.HuddlLive do
  @moduledoc """
  LiveView at `/discover`. Renders combined search across huddlz and groups —
  the active resource type is selected by the `?scope=huddlz|groups` URL param
  (defaults to `huddlz`). The legacy `?yours=hosting|attending` param scopes
  the huddl results to the actor's relationship; it is huddl-only and ignored
  under `scope=groups`. Personal sections live on the dedicated routes
  (`/my-huddlz`, `/my-groups`); this view is shared by anonymous and
  signed-in users.
  """
  use HuddlzWeb, :live_view

  alias Huddlz.Communities
  alias Huddlz.Storage.GroupImages
  alias Huddlz.Storage.HuddlImages
  alias HuddlzWeb.Layouts
  require Logger

  @huddl_card_loads [:status, :rsvp_count, :visible_virtual_link, :display_image_url, :group]
  @page_size 20

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_optional}
  on_mount {HuddlzWeb.LiveUserAuth, :app}

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

  def handle_event("distance_change", %{"distance_miles" => raw}, socket) do
    new_distance = parse_distance(raw)

    if new_distance == socket.assigns.distance_miles do
      {:noreply, socket}
    else
      params =
        socket
        |> form_params_from_assigns()
        |> Map.put("distance_miles", Integer.to_string(new_distance))

      {:noreply,
       push_patch(socket,
         to: scoped_path(socket.assigns.scope, socket.assigns.yours, params)
       )}
    end
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
      {:noreply, socket}
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
      page: Keyword.get(opts, :page, []),
      load: @huddl_card_loads
    )
  end

  defp list_groups(query, page, actor) do
    case Communities.search_groups(query,
           actor: actor,
           query: [filter: [is_public: true]],
           load: [:current_image_url, :member_count],
           page: [
             limit: @page_size,
             offset: (page - 1) * @page_size,
             count: true
           ]
         ) do
      {:ok, %{results: results, count: count}} ->
        {results, count || 0}

      {:error, reason} ->
        Logger.warning("HuddlLive group search failed: #{inspect(reason)}")
        {[], 0}
    end
  end

  defp load_results_with_distances({:ok, %{results: results}}, socket) do
    dists = compute_distances(results, socket)
    {results, dists}
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

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      sidebar_owned_groups={@sidebar_owned_groups}
      active="discover"
      query={@search_query || ""}
    >
      <div class="page-head">
        <div>
          <h1>{discover_h1(@scope, @yours, @search_query)}</h1>
          <p :if={discover_subtitle(@scope, @yours, @search_query, @location_text)}>
            {discover_subtitle(@scope, @yours, @search_query, @location_text)}
          </p>
        </div>
      </div>

      <div :if={@yours != :all} class="discover-back">
        <.link patch={view_all_path(:all, assigns)} class="muted">
          ← All huddlz
        </.link>
      </div>

      <div class="scope-tabs">
        <.link
          patch={chip_path(:huddlz, assigns)}
          class={["scope-tab", @scope == :huddlz && "is-active"]}
        >
          Huddlz
        </.link>
        <.link
          patch={chip_path(:groups, assigns)}
          class={["scope-tab", @scope == :groups && "is-active"]}
        >
          Groups
        </.link>
      </div>

      <div :if={@scope == :huddlz} class="filter-bar">
        <div class="filter-group">
          <span class="filter-label">Within</span>
          <.live_component
            module={HuddlzWeb.Live.LocationAutocomplete}
            id="location-autocomplete"
            variant={:filter_pill}
            value={@location_text}
            latitude={@location_lat}
            longitude={@location_lng}
            placeholder="Anywhere"
          />
          <%!-- A `<form>` wraps the slider so phx-change emits a clean
                `name=value` payload. `display: contents` flattens the form so
                it doesn't perturb the .filter-distance flex layout. --%>
          <form
            :if={@location_active}
            class="filter-distance"
            phx-change="distance_change"
            style="display:contents"
          >
            <input
              id="distance"
              type="range"
              name="distance_miles"
              min="5"
              max="100"
              step="5"
              value={@distance_miles}
              phx-debounce="200"
            />
            <output for="distance" class="filter-distance-value">{@distance_miles} mi</output>
          </form>
        </div>

        <div class="filter-group">
          <span class="filter-label">Type</span>
          <div class="chip-group">
            <.chip
              patch={format_toggle_url("in_person", assigns)}
              active={@event_type_filter == "in_person"}
            >
              In person
            </.chip>
            <.chip
              patch={format_toggle_url("virtual", assigns)}
              active={@event_type_filter == "virtual"}
            >
              Virtual
            </.chip>
            <.chip
              patch={format_toggle_url("hybrid", assigns)}
              active={@event_type_filter == "hybrid"}
            >
              Hybrid
            </.chip>
          </div>
        </div>

        <div class="filter-group">
          <span class="filter-label">When</span>
          <div class="chip-group">
            <.chip
              patch={date_toggle_url("upcoming", assigns)}
              active={@date_filter == "upcoming"}
            >
              All upcoming
            </.chip>
            <.chip
              patch={date_toggle_url("this_week", assigns)}
              active={@date_filter == "this_week"}
            >
              This week
            </.chip>
            <.chip
              patch={date_toggle_url("this_month", assigns)}
              active={@date_filter == "this_month"}
            >
              This month
            </.chip>
          </div>
        </div>

        <div class="filter-group">
          <span class="filter-label">Sort</span>
          <div class="chip-group">
            <.chip patch={sort_toggle_url("soonest", assigns)} active={@sort == :soonest}>
              Soonest
            </.chip>
            <.chip patch={sort_toggle_url("newest", assigns)} active={@sort == :newest}>
              Newest
            </.chip>
          </div>
        </div>
      </div>

      <div class="discover-meta">
        {result_count_label(@page_info.total_count, @scope)}
        <span :if={any_filter_active?(assigns)}>
          ·
          <button type="button" phx-click="clear_filters" class="button-link">
            Clear filters
          </button>
        </span>
      </div>

      <%= if @scope == :huddlz do %>
        <%= if Enum.empty?(@huddls) do %>
          <p class="muted">{empty_message(assigns)}</p>
        <% else %>
          <div class="grid">
            <%= for {{huddl, distance}, idx} <- Enum.with_index(@huddls) do %>
              <.huddl_card huddl={huddl} distance={distance} gradient={Integer.mod(idx, 6) + 1} />
            <% end %>
          </div>
          <.pagination
            :if={@page_info.total_pages > 1}
            current_page={@page_info.current_page}
            total_pages={@page_info.total_pages}
            event_name="change_page"
          />
        <% end %>
      <% else %>
        <%= if @groups == [] do %>
          <p class="muted">{empty_message(assigns)}</p>
        <% else %>
          <div class="grid">
            <%= for {group, idx} <- Enum.with_index(@groups) do %>
              <.group_card group={group} gradient={Integer.mod(idx, 6) + 1} />
            <% end %>
          </div>
          <.pagination
            :if={@page_info.total_pages > 1}
            current_page={@page_info.current_page}
            total_pages={@page_info.total_pages}
            event_name="change_page"
          />
        <% end %>
      <% end %>
    </Layouts.app>
    """
  end

  attr :huddl, :map, required: true
  attr :distance, :float, default: nil
  attr :gradient, :integer, default: 1

  defp huddl_card(assigns) do
    ~H"""
    <.card
      navigate={~p"/groups/#{@huddl.group.slug}/huddlz/#{@huddl.id}"}
      gradient={@gradient}
    >
      <:cover>
        <img
          :if={@huddl.display_image_url}
          class="card-cover-img"
          src={HuddlImages.url(@huddl.display_image_url)}
          alt={@huddl.title}
        />
        <.date_stamp month={huddl_month(@huddl)} day={huddl_day(@huddl)} />
        <.card_tag variant={tag_variant(@huddl.event_type)}>
          {tag_label(@huddl.event_type)}
        </.card_tag>
      </:cover>
      <:body>
        <span :if={Map.has_key?(@huddl, :group) && @huddl.group} class="card-group">
          {@huddl.group.name}
        </span>
        <h3 class="card-title">{@huddl.title}</h3>
        <div class="card-meta">
          <span>{format_meta_when(@huddl.starts_at)}</span>
          <%= if @distance do %>
            <span class="dot"></span>
            <span>{format_distance(@distance)}</span>
          <% end %>
          <%= if @huddl.rsvp_count > 0 || @huddl.max_attendees do %>
            <span class="dot"></span>
            <span>{rsvp_label(@huddl)}</span>
          <% end %>
        </div>
      </:body>
    </.card>
    """
  end

  attr :group, :map, required: true
  attr :gradient, :integer, default: 1

  defp group_card(assigns) do
    ~H"""
    <.card navigate={~p"/groups/#{@group.slug}"} gradient={@gradient}>
      <:cover>
        <img
          :if={@group.current_image_url}
          class="card-cover-img"
          src={GroupImages.url(@group.current_image_url)}
          alt={@group.name}
        />
      </:cover>
      <:body>
        <span :if={@group.location} class="card-group">{@group.location}</span>
        <h2 class="card-title">{@group.name}</h2>
        <div :if={member_count_label(@group)} class="card-meta">
          <span>{member_count_label(@group)}</span>
        </div>
      </:body>
    </.card>
    """
  end

  defp discover_h1(_, :hosting, _), do: "huddlz you're hosting"
  defp discover_h1(_, :attending, _), do: "huddlz you're attending"

  defp discover_h1(_, _, q) when is_binary(q) and q != "",
    do: "Results for “#{q}”"

  defp discover_h1(:groups, _, _), do: "Browse groups"
  defp discover_h1(:huddlz, _, _), do: "Browse huddlz"

  defp discover_subtitle(_, yours, _, _) when yours in [:hosting, :attending], do: nil

  defp discover_subtitle(:huddlz, _, q, location) do
    base =
      if is_binary(q) and q != "",
        do: "Showing huddlz that match your search",
        else: "Find a huddl worth showing up to. Tweak the filters to match what you're after"

    location_suffix = if location, do: " near #{location}", else: ""
    base <> location_suffix <> "."
  end

  defp discover_subtitle(:groups, _, q, _location) do
    if is_binary(q) and q != "" do
      "Groups matching your search."
    else
      "Communities organizing huddlz."
    end
  end

  defp result_count_label(count, :huddlz),
    do: "#{count} #{if count == 1, do: "huddl", else: "huddlz"}"

  defp result_count_label(count, :groups),
    do: "#{count} #{if count == 1, do: "group", else: "groups"}"

  defp tag_variant(:in_person), do: :in_person
  defp tag_variant(:virtual), do: :online
  defp tag_variant(:hybrid), do: :hybrid

  defp tag_label(:in_person), do: "In person"
  defp tag_label(:virtual), do: "Online"
  defp tag_label(:hybrid), do: "Hybrid"

  defp huddl_month(%{starts_at: %DateTime{} = dt}),
    do: Calendar.strftime(dt, "%b") |> String.upcase()

  defp huddl_day(%{starts_at: %DateTime{} = dt}), do: Calendar.strftime(dt, "%-d")

  defp format_meta_when(%DateTime{} = dt) do
    "#{Calendar.strftime(dt, "%a")} · #{Calendar.strftime(dt, "%-I:%M %p")}"
  end

  defp format_distance(miles) when is_number(miles) and miles < 1, do: "< 1 mi"

  defp format_distance(miles) when is_number(miles) do
    rounded = Float.round(miles * 1.0, 1)
    if rounded == trunc(rounded), do: "#{trunc(rounded)} mi", else: "#{rounded} mi"
  end

  defp rsvp_label(%{rsvp_count: count, max_attendees: max}) when is_integer(max) and max > 0,
    do: "#{count} / #{max} RSVPs"

  defp rsvp_label(%{rsvp_count: 1}), do: "1 RSVP"
  defp rsvp_label(%{rsvp_count: count}), do: "#{count} RSVPs"

  defp member_count_label(group) do
    case Map.get(group, :member_count) do
      1 -> "1 member"
      n when is_integer(n) and n > 0 -> "#{n} members"
      _ -> nil
    end
  end

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
end
