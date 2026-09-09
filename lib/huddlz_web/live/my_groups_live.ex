defmodule HuddlzWeb.MyGroupsLive do
  @moduledoc """
  LiveView at `/groups`. Personal feed of groups the signed-in user
  organizes (Hosting) or has joined (Joined). Filter chips drive a
  `?filter=` URL param: default `all` is no param, `hosting` and `joined`
  scope the grid. `?page=N` paginates the active filter.

  All sorting and pagination happens in postgres via the `:my_groups` read
  action — we do not sort in code.
  """
  use HuddlzWeb, :live_view

  import HuddlzWeb.Live.Helpers.ParamHelpers

  alias Huddlz.Communities
  alias HuddlzWeb.Layouts
  require Logger

  @group_loads [:current_image_url, :member_count, :viewer_role]
  @page_size 20
  @valid_filters ~w(all hosting joined archived)

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_required}
  on_mount {HuddlzWeb.LiveUserAuth, :app}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Groups")
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
  def handle_info(
        {:organizer_access_changed, user_id},
        %{assigns: %{current_user: %{id: user_id}}} = socket
      ) do
    user = socket.assigns.current_user
    filter = socket.assigns.filter

    {:noreply,
     socket
     |> assign(:counts, load_counts(user))
     |> load_results(filter, 1, user)
     |> push_patch(to: filter_path(filter, 1))}
  end

  @impl true
  def handle_event("change_page", %{"page" => page_str}, socket) do
    page = parse_page(page_str)
    {:noreply, push_patch(socket, to: filter_path(socket.assigns.filter, page))}
  end

  defp parse_filter(value) when value in @valid_filters, do: String.to_existing_atom(value)
  defp parse_filter(_), do: :all

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

  defp list_groups(:archived, opts), do: Communities.archived_groups(opts)
  defp list_groups(filter, opts), do: Communities.my_groups(filter, opts)

  defp load_results(socket, filter, page, user) do
    offset = (page - 1) * @page_size

    case list_groups(filter,
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

  defp filter_path(:all, page) when page > 1, do: ~p"/groups?#{[page: page]}"
  defp filter_path(:all, _page), do: ~p"/groups"

  defp filter_path(filter, page) when page > 1,
    do: ~p"/groups?#{[filter: filter, page: page]}"

  defp filter_path(filter, _page), do: ~p"/groups?#{[filter: filter]}"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      unread_notification_count={@unread_notification_count}
      sidebar_owned_groups={@sidebar_owned_groups}
      active="groups"
    >
      <div class="page-head">
        <div>
          <h1>Groups</h1>
          <p>{filter_blurb(@filter)}</p>
        </div>
        <.button
          variant={if @counts.all == 0, do: :secondary, else: :primary}
          navigate={~p"/groups/new"}
        >
          <.icon name="hero-plus" class="size-4" /> Start a group
        </.button>
      </div>

      <div class="filters">
        <.chip patch={filter_path(:all, 1)} active={@filter == :all} count={@counts.all}>
          All
        </.chip>
        <.chip
          patch={filter_path(:hosting, 1)}
          active={@filter == :hosting}
          count={@counts.hosting}
        >
          Hosting
        </.chip>
        <.chip patch={filter_path(:joined, 1)} active={@filter == :joined} count={@counts.joined}>
          Joined
        </.chip>
        <.chip patch={filter_path(:archived, 1)} active={@filter == :archived}>Archived</.chip>
      </div>

      <%= if Enum.empty?(@groups) do %>
        <.empty_state
          icon={empty_icon(@filter)}
          title={empty_title(@filter)}
          data-first-run={@filter == :all || nil}
        >
          {empty_message(@filter)}
          <:action :if={@filter == :all}>
            <.button variant={:primary} navigate={~p"/discover?scope=groups"}>
              <.icon name="hero-magnifying-glass" class="size-4" /> Browse groups
            </.button>
            <.button variant={:secondary} navigate={~p"/groups/new"}>Start your own</.button>
          </:action>
          <:action :if={@filter == :joined}>
            <.button variant={:secondary} navigate={~p"/discover?scope=groups"}>
              Browse groups
            </.button>
          </:action>
        </.empty_state>
      <% else %>
        <div class="grid">
          <.my_group_card :for={group <- @groups} group={group} role={group.viewer_role} />
        </div>
        <.pagination
          :if={@page_info.total_pages > 1}
          current_page={@page_info.current_page}
          total_pages={@page_info.total_pages}
          event_name="change_page"
        />
      <% end %>
    </Layouts.app>
    """
  end

  attr :group, :map, required: true
  attr :role, :atom, required: true

  defp my_group_card(assigns) do
    ~H"""
    <.card navigate={~p"/groups/#{@group.slug}"}>
      <:cover>
        <.group_cover id={"my-group-cover-#{@group.id}"} group={@group} />
        <span class={["card-tag", role_class(@role)]}>{HuddlzWeb.GroupRole.label(@role)}</span>
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

  defp filter_blurb(:archived), do: "Closed groups whose history you can revisit."

  defp filter_blurb(:all), do: "Groups you organize and groups you've joined."
  defp filter_blurb(:hosting), do: "Groups you organize."
  defp filter_blurb(:joined), do: "Groups you've joined."

  defp empty_icon(:archived), do: "hero-archive-box"

  defp empty_icon(:all), do: "hero-user-group"
  defp empty_icon(:hosting), do: "hero-megaphone"
  defp empty_icon(:joined), do: "hero-user-plus"

  defp empty_title(:archived), do: "No archived groups"

  defp empty_title(:all), do: "No groups yet"
  defp empty_title(:hosting), do: "You're not hosting a group"
  defp empty_title(:joined), do: "No groups joined"

  defp empty_message(:archived), do: "Your archived groups will appear here."

  # An empty "All" is a first run: the account belongs to no group at all,
  # so this page explains what groups are for and offers both ways in.
  defp empty_message(:all),
    do: "Groups are where huddlz come from. Join one to follow its huddlz, or start your own."

  defp empty_message(:hosting), do: "Start a group and its huddlz will show up here."
  defp empty_message(:joined), do: "Join a group to follow its huddlz here."

  defp role_class(:owner), do: "owner"
  defp role_class(:organizer), do: "organizer"
  defp role_class(_), do: nil

  defp member_count_label(group) do
    case Map.get(group, :member_count) do
      1 -> "1 member"
      n when is_integer(n) and n > 0 -> "#{n} members"
      _ -> nil
    end
  end
end
