defmodule HuddlzWeb.GroupLive.Index do
  @moduledoc """
  LiveView for listing and searching groups, with personal sections for
  authenticated users (Hosting, Joined) and a public directory.
  """
  use HuddlzWeb, :live_view

  alias Huddlz.Communities
  alias Huddlz.Communities.Group
  alias HuddlzWeb.Layouts
  require Logger

  @section_limit 6
  @page_size 20

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_optional}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:can_create_group, Ash.can?({Group, :create_group}, socket.assigns.current_user))
     |> assign(:query, nil)
     |> assign(:scope, :all)
     |> assign(:section_limit, @section_limit)
     |> assign(:hosting, [])
     |> assign(:joined, [])
     |> assign(:hosting_total, 0)
     |> assign(:joined_total, 0)
     |> assign(:groups, [])
     |> assign(:page_info, %{total_pages: 1, current_page: 1, total_count: 0})}
  end

  @impl true
  def handle_params(params, _url, socket) do
    scope = parse_scope(params["yours"])
    query = params["q"] |> normalize_query()

    if scope != :all and is_nil(socket.assigns.current_user) do
      {:noreply,
       socket
       |> put_flash(:error, "Sign in to view #{sign_in_prompt(scope)}.")
       |> push_navigate(to: ~p"/sign-in")}
    else
      page = parse_page(params["page"])

      socket =
        socket
        |> assign(:page_title, page_title(scope))
        |> assign(:scope, scope)
        |> assign(:query, query)
        |> load_groups(page)

      total_pages = socket.assigns.page_info.total_pages

      if page > total_pages do
        # Out-of-range page: clamp by patching to the last valid page so the URL
        # reflects what the user actually sees.
        {:noreply, push_patch(socket, to: scoped_path(scope, query, page: total_pages))}
      else
        {:noreply, socket}
      end
    end
  end

  defp sign_in_prompt(:hosting), do: "groups you host"
  defp sign_in_prompt(:joined), do: "groups you've joined"

  @impl true
  def handle_event("filter_change", %{"query" => query}, socket) do
    {:noreply, push_patch(socket, to: scoped_path(socket.assigns.scope, query))}
  end

  def handle_event("search", %{"query" => query}, socket) do
    {:noreply, push_patch(socket, to: scoped_path(socket.assigns.scope, query))}
  end

  def handle_event("clear_search", _params, socket) do
    {:noreply, push_patch(socket, to: scoped_path(socket.assigns.scope, nil))}
  end

  def handle_event("change_page", %{"page" => page_str}, socket) do
    page = parse_page(page_str)

    path = scoped_path(socket.assigns.scope, socket.assigns.query, page: page)

    {:noreply, push_patch(socket, to: path)}
  end

  defp parse_scope("hosting"), do: :hosting
  defp parse_scope("joined"), do: :joined
  defp parse_scope(_), do: :all

  defp normalize_query(nil), do: nil
  defp normalize_query(""), do: nil
  defp normalize_query(q) when is_binary(q), do: q |> String.trim() |> nilify_blank()

  defp nilify_blank(""), do: nil
  defp nilify_blank(q), do: q

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

  defp page_title(:hosting), do: "Groups You Host"
  defp page_title(:joined), do: "Groups You've Joined"
  defp page_title(:all), do: "Groups"

  defp scoped_path(scope, query, opts \\ []) do
    page = Keyword.get(opts, :page, 1)

    params =
      [yours: scope_param(scope), q: query, page: page_param(page)]
      |> Enum.reject(fn {_, v} -> is_nil(v) end)

    case params do
      [] -> ~p"/groups"
      params -> ~p"/groups?#{params}"
    end
  end

  defp page_param(page) when is_integer(page) and page > 1, do: Integer.to_string(page)
  defp page_param(_), do: nil

  defp scope_param(:hosting), do: "hosting"
  defp scope_param(:joined), do: "joined"
  defp scope_param(:all), do: nil

  defp load_groups(socket, page) do
    user = socket.assigns.current_user
    query = socket.assigns.query

    case socket.assigns.scope do
      :hosting ->
        {groups, total} = list_hosting(user, query, page)

        socket
        |> assign(:groups, groups)
        |> assign(:page_info, page_info(total, page))

      :joined ->
        {groups, total} = list_joined(user, query, page)

        socket
        |> assign(:groups, groups)
        |> assign(:page_info, page_info(total, page))

      :all ->
        hosting = if user, do: list_hosting_section(user, query), else: []
        joined = if user, do: list_joined_section(user, query), else: []
        {groups, total} = list_all(query, page)

        socket
        |> assign(:hosting, Enum.take(hosting, @section_limit))
        |> assign(:hosting_total, length(hosting))
        |> assign(:joined, Enum.take(joined, @section_limit))
        |> assign(:joined_total, length(joined))
        |> assign(:groups, groups)
        |> assign(:page_info, page_info(total, page))
    end
  end

  # Personal sections aren't paginated — they show up to @section_limit and
  # link out to the scoped (paginated) view via "View all".
  defp list_hosting_section(user, query) do
    Communities.get_by_owner(search_input(query), actor: user, load: [:current_image_url])
    |> unwrap_section()
  end

  defp list_joined_section(user, query) do
    Communities.get_joined_groups(search_input(query), actor: user, load: [:current_image_url])
    |> unwrap_section()
  end

  defp list_hosting(user, query, page) do
    Communities.get_by_owner(search_input(query),
      actor: user,
      load: [:current_image_url],
      page: page_opts(page)
    )
    |> unwrap_page(page)
  end

  defp list_joined(user, query, page) do
    Communities.get_joined_groups(search_input(query),
      actor: user,
      load: [:current_image_url],
      page: page_opts(page)
    )
    |> unwrap_page(page)
  end

  defp search_input(nil), do: %{}
  defp search_input(query) when is_binary(query), do: %{search: query}

  # The main directory stays public-only on purpose: a user's private groups
  # already surface in the // JOINED section above, so re-listing them here
  # would just duplicate. Anonymous users can only ever see public groups.
  defp list_all(query, page) do
    Communities.search_groups(query,
      actor: nil,
      query: [filter: [is_public: true]],
      load: [:current_image_url],
      page: page_opts(page)
    )
    |> unwrap_page(page)
  end

  defp page_opts(page) do
    [limit: @page_size, offset: (page - 1) * @page_size, count: true]
  end

  defp unwrap_section({:ok, groups}), do: groups

  defp unwrap_section({:error, reason}) do
    Logger.warning("GroupLive.Index group section read failed: #{inspect(reason)}")
    []
  end

  defp unwrap_page({:ok, %{results: results, count: count}}, _page), do: {results, count || 0}

  defp unwrap_page({:error, reason}, _page) do
    Logger.warning("GroupLive.Index group page read failed: #{inspect(reason)}")
    {[], 0}
  end

  defp page_info(0, _page),
    do: %{total_pages: 1, current_page: 1, total_count: 0}

  defp page_info(total, page) when total > 0 do
    total_pages = ceil(total / @page_size)
    %{total_pages: total_pages, current_page: page, total_count: total}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.header>
        {page_title(@scope)}
        <:actions :if={@can_create_group}>
          <.button navigate={~p"/groups/new"}>New Group</.button>
        </:actions>
      </.header>

      <form phx-change="filter_change" phx-submit="search" class="mt-6">
        <div class="flex items-end gap-2">
          <div class="flex-grow">
            <label for="group-search" class="sr-only">Search groups</label>
            <input
              id="group-search"
              type="text"
              name="query"
              value={@query}
              placeholder="Search groups"
              phx-debounce="300"
              class="w-full h-12 pl-0 pr-4 border-0 border-b border-base-300 bg-transparent text-base focus:outline-none focus:ring-0 focus:border-primary transition-colors placeholder:text-base-content/30"
            />
          </div>
          <%= if @query do %>
            <.button variant="ghost" size="sm" type="button" phx-click="clear_search">
              Clear
            </.button>
          <% end %>
        </div>
      </form>

      <%= if @scope == :all and @current_user do %>
        <.personal_section
          :if={@hosting_total > 0}
          title="Hosting"
          count={@hosting_total}
          groups={@hosting}
          limit={@section_limit}
          query={@query}
          yours="hosting"
        />
        <.personal_section
          :if={@joined_total > 0}
          title="Joined"
          count={@joined_total}
          groups={@joined}
          limit={@section_limit}
          query={@query}
          yours="joined"
        />
      <% end %>

      <div class="mt-10">
        <h2
          :if={show_all_heading?(assigns)}
          class="font-display text-lg tracking-tight text-glow flex items-baseline gap-3"
        >
          <span class="mono-label text-primary/70">// {scope_heading(@scope)}</span>
          <span class="text-sm font-body font-normal text-base-content/40">
            ({@page_info.total_count})
          </span>
        </h2>

        <%= if @groups == [] do %>
          <div class="border border-dashed border-base-300 p-12 text-center mt-4">
            <p class="text-lg text-base-content/40">{empty_message(@scope, @query)}</p>
            <%= if @scope == :all and @can_create_group and is_nil(@query) do %>
              <p class="mt-4">
                <.link navigate={~p"/groups/new"} class="text-primary hover:underline font-medium">
                  Create the first group
                </.link>
              </p>
            <% end %>
          </div>
        <% else %>
          <div class={[
            "grid gap-6 sm:grid-cols-2 lg:grid-cols-3",
            show_all_heading?(assigns) && "mt-4"
          ]}>
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

        <div :if={@scope != :all} class="mt-6">
          <.link navigate={~p"/groups"} class="text-sm text-primary hover:underline font-medium">
            ← All groups
          </.link>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :title, :string, required: true
  attr :count, :integer, required: true
  attr :groups, :list, required: true
  attr :limit, :integer, required: true
  attr :query, :string, default: nil
  attr :yours, :string, required: true

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
          navigate={view_all_path(@yours, @query)}
          class="text-xs text-primary hover:underline font-medium tracking-wide uppercase"
        >
          View all →
        </.link>
      </div>

      <div class="grid gap-6 sm:grid-cols-2 lg:grid-cols-3 mt-4">
        <%= for group <- @groups do %>
          <.group_card group={group} />
        <% end %>
      </div>
    </div>
    """
  end

  defp view_all_path(yours, nil), do: ~p"/groups?#{[yours: yours]}"
  defp view_all_path(yours, query), do: ~p"/groups?#{[yours: yours, q: query]}"

  defp scope_heading(:hosting), do: "Hosting"
  defp scope_heading(:joined), do: "Joined"
  defp scope_heading(:all), do: "All Groups"

  defp show_all_heading?(%{scope: :all, current_user: user, hosting_total: h, joined_total: j})
       when not is_nil(user) and (h > 0 or j > 0),
       do: true

  defp show_all_heading?(_), do: false

  defp empty_message(_scope, query) when not is_nil(query), do: "No groups match your search."
  defp empty_message(:hosting, _), do: "You aren't hosting any groups yet."
  defp empty_message(:joined, _), do: "You haven't joined any groups yet."
  defp empty_message(:all, _), do: "No groups found."
end
