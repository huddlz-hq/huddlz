defmodule HuddlzWeb.MyGroupsLive do
  @moduledoc """
  LiveView at `/my-groups`. Personal feed of groups the signed-in user
  organizes (Hosting) or has joined (Joined). Filter chips drive a
  `?filter=` URL param: default `all` is no param, `hosting` and `joined`
  scope the grid. `?page=N` paginates the active filter.

  All sorting and pagination happens in postgres via the `:my_groups` read
  action — we do not sort in code.
  """
  use HuddlzWeb, :live_view

  alias Huddlz.Communities
  alias Huddlz.Storage.GroupImages
  alias HuddlzWeb.Layouts
  require Logger

  @group_loads [:current_image_url, :member_count]
  @page_size 20
  @valid_filters ~w(all hosting joined)

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_required}
  on_mount {HuddlzWeb.LiveUserAuth, :v3_app}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "My groups")
     |> assign(:groups, [])
     |> assign(:counts, %{all: 0, hosting: 0, joined: 0})
     |> assign(:page_info, %{total_pages: 1, current_page: 1, total_count: 0})}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filter = parse_filter(params["filter"])
    page = parse_page(params["page"])
    user = socket.assigns.current_user

    socket =
      socket
      |> assign(:filter, filter)
      |> assign(:counts, load_counts(user))
      |> load_results(filter, page, user)

    total_pages = socket.assigns.page_info.total_pages

    if page > total_pages do
      {:noreply, push_patch(socket, to: filter_path(filter, total_pages))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("change_page", %{"page" => page_str}, socket) do
    page = parse_page(page_str)
    {:noreply, push_patch(socket, to: filter_path(socket.assigns.filter, page))}
  end

  defp parse_filter(value) when value in @valid_filters, do: String.to_existing_atom(value)
  defp parse_filter(_), do: :all

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

  defp load_counts(user) do
    %{
      all: count_for(user, :all),
      hosting: count_for(user, :hosting),
      joined: count_for(user, :joined)
    }
  end

  defp count_for(user, relationship) do
    case Communities.my_groups(relationship,
           actor: user,
           page: [limit: 1, offset: 0, count: true]
         ) do
      {:ok, %{count: count}} when is_integer(count) -> count
      _ -> 0
    end
  end

  defp load_results(socket, filter, page, user) do
    offset = (page - 1) * @page_size

    case Communities.my_groups(filter,
           actor: user,
           load: @group_loads,
           page: [limit: @page_size, offset: offset, count: true]
         ) do
      {:ok, %Ash.Page.Offset{results: results, count: count}} ->
        total_pages = if count && count > 0, do: ceil(count / @page_size), else: 1

        socket
        |> assign(:groups, results)
        |> assign(:page_info, %{
          total_pages: total_pages,
          current_page: page,
          total_count: count || 0
        })

      {:error, reason} ->
        Logger.warning("MyGroupsLive load failed: #{inspect(reason)}")

        socket
        |> assign(:groups, [])
        |> assign(:page_info, %{total_pages: 1, current_page: 1, total_count: 0})
    end
  end

  defp filter_path(:all, page) when page > 1, do: ~p"/my-groups?#{[page: page]}"
  defp filter_path(:all, _page), do: ~p"/my-groups"

  defp filter_path(filter, page) when page > 1,
    do: ~p"/my-groups?#{[filter: filter, page: page]}"

  defp filter_path(filter, _page), do: ~p"/my-groups?#{[filter: filter]}"

  defp role_for(group, user) do
    if group.owner_id == user.id, do: :hosting, else: :joined
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.v3_app flash={@flash} current_user={@current_user} active="my-groups">
      <div class="page-head">
        <div>
          <h1>My groups</h1>
          <p>{filter_blurb(@filter)}</p>
        </div>
        <.link navigate={~p"/groups/new"} class="btn-primary">
          Start a group
        </.link>
      </div>

      <div class="filters">
        <.v3_chip patch={filter_path(:all, 1)} active={@filter == :all}>
          All · {@counts.all}
        </.v3_chip>
        <.v3_chip patch={filter_path(:hosting, 1)} active={@filter == :hosting}>
          Hosting · {@counts.hosting}
        </.v3_chip>
        <.v3_chip patch={filter_path(:joined, 1)} active={@filter == :joined}>
          Joined · {@counts.joined}
        </.v3_chip>
      </div>

      <%= if Enum.empty?(@groups) do %>
        <p class="muted">{empty_message(@filter)}</p>
      <% else %>
        <div class="grid">
          <%= for {group, idx} <- Enum.with_index(@groups) do %>
            <.v3_my_group_card
              group={group}
              role={role_for(group, @current_user)}
              gradient={Integer.mod(idx, 6) + 1}
            />
          <% end %>
        </div>
        <.v3_pagination
          :if={@page_info.total_pages > 1}
          current_page={@page_info.current_page}
          total_pages={@page_info.total_pages}
          event_name="change_page"
        />
      <% end %>
    </Layouts.v3_app>
    """
  end

  attr :group, :map, required: true
  attr :role, :atom, required: true
  attr :gradient, :integer, required: true

  defp v3_my_group_card(assigns) do
    ~H"""
    <.v3_card navigate={~p"/groups/#{@group.slug}"} gradient={@gradient}>
      <:cover>
        <img
          :if={@group.current_image_url}
          class="card-cover-img"
          src={GroupImages.url(@group.current_image_url)}
          alt={@group.name}
        />
        <span class={["card-tag", role_class(@role)]}>{role_label(@role)}</span>
      </:cover>
      <:body>
        <span :if={@group.location} class="card-group">{@group.location}</span>
        <h2 class="card-title">{@group.name}</h2>
        <div :if={member_count_label(@group)} class="card-meta">
          <span>{member_count_label(@group)}</span>
        </div>
      </:body>
    </.v3_card>
    """
  end

  defp filter_blurb(:all), do: "Groups you organize and groups you've joined."
  defp filter_blurb(:hosting), do: "Groups you organize."
  defp filter_blurb(:joined), do: "Groups you've joined."

  defp empty_message(:all),
    do: "You haven't organized or joined any groups yet. Start one or browse Discover."

  defp empty_message(:hosting), do: "You haven't created a group yet."
  defp empty_message(:joined), do: "You haven't joined any groups yet."

  defp role_class(:hosting), do: "hybrid"
  defp role_class(:joined), do: "in-person"

  defp role_label(:hosting), do: "Hosting"
  defp role_label(:joined), do: "Joined"

  defp member_count_label(group) do
    case Map.get(group, :member_count) do
      1 -> "1 member"
      n when is_integer(n) and n > 0 -> "#{n} members"
      _ -> nil
    end
  end
end
