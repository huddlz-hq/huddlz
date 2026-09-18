defmodule HuddlzWeb.GroupsLive do
  @moduledoc """
  LiveView at `/groups`. Personal feed of groups the signed-in user
  organizes (Hosting) or has joined (Joined). Filter chips drive a
  `?filter=` URL param: default `all` is no param, `hosting` and `joined`
  scope the grid. `?page=N` paginates the active filter.

  Membership sorting and pagination happens in postgres via the
  `:groups_for_actor` read action.

  Under the default view, after the person's own groups, a short section
  lists the groups they have dropped in on: RSVPd to a huddl of, without
  joining (`Communities.list_drop_ins/2`). Each can be joined or answered
  "Not now" in place; the section is absent when there is nothing to show.
  """
  use HuddlzWeb, :live_view

  import HuddlzWeb.Live.Helpers.ParamHelpers

  alias Huddlz.Communities
  alias HuddlzWeb.Layouts
  alias HuddlzWeb.Live.Helpers.HuddlCardHelpers
  require Logger

  @group_loads [:current_image_url, :member_count, :viewer_role]
  @page_size 20
  @drop_ins_visible 6
  @valid_filters ~w(all hosting joined archived)

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_required}
  on_mount {HuddlzWeb.LiveUserAuth, :app}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Groups")
     |> assign(:groups, [])
     |> stream(:drop_ins, [], dom_id: &"dropped-in-#{&1.group.id}")
     |> assign(:drop_ins_count, 0)
     |> assign(:drop_ins_expanded?, false)
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
      |> load_drop_ins(filter, page, user)

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

  def handle_event("join_dropped_in", %{"group-id" => group_id}, socket) do
    user = socket.assigns.current_user

    with %{group: group} <- find_drop_in(socket, group_id),
         {:ok, _membership} <- Communities.join_group(group.id, actor: user) do
      {:noreply,
       socket
       |> put_flash(:info, "You joined #{group.name}.")
       |> assign(:counts, load_counts(user))
       |> load_results(socket.assigns.filter, socket.assigns.page_info.current_page, user)
       |> load_drop_ins(socket.assigns.filter, socket.assigns.page_info.current_page, user)}
    else
      _ -> {:noreply, put_flash(socket, :error, "Couldn't join the group. Please try again.")}
    end
  end

  def handle_event("dismiss_dropped_in", %{"group-id" => group_id}, socket) do
    user = socket.assigns.current_user

    with %{group: group} <- find_drop_in(socket, group_id),
         {:ok, _reminder} <- Communities.dismiss_join_suggestion(group.id, actor: user) do
      {:noreply,
       load_drop_ins(socket, socket.assigns.filter, socket.assigns.page_info.current_page, user)}
    else
      _ -> {:noreply, put_flash(socket, :error, "Couldn't save that. Please try again.")}
    end
  end

  def handle_event("show_all_dropped_in", _params, socket) do
    {:noreply,
     socket
     |> assign(:drop_ins_expanded?, true)
     |> load_drop_ins(
       socket.assigns.filter,
       socket.assigns.page_info.current_page,
       socket.assigns.current_user
     )}
  end

  defp find_drop_in(socket, group_id) do
    case Communities.list_drop_ins(actor: socket.assigns.current_user) do
      {:ok, %{entries: entries}} -> Enum.find(entries, &(&1.group.id == group_id))
      {:error, _reason} -> nil
    end
  end

  # The section belongs to the default view's first page: it follows the
  # person's own groups rather than any one filter of them.
  defp load_drop_ins(socket, :all, 1, user) do
    limit = if socket.assigns.drop_ins_expanded?, do: nil, else: @drop_ins_visible

    case Communities.list_drop_ins(%{limit: limit}, actor: user) do
      {:ok, %{entries: entries, count: count}} ->
        socket
        |> assign(:drop_ins_count, count)
        |> stream(:drop_ins, entries, reset: true)

      {:error, reason} ->
        Logger.warning("GroupsLive drop-ins load failed: #{inspect(reason)}")
        clear_drop_ins(socket)
    end
  end

  defp load_drop_ins(socket, _filter, _page, _user), do: clear_drop_ins(socket)

  defp clear_drop_ins(socket) do
    socket
    |> assign(:drop_ins_count, 0)
    |> stream(:drop_ins, [], reset: true)
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
    case Communities.groups_for_actor(relationship,
           actor: user,
           page: [limit: 1, offset: 0, count: true]
         ) do
      {:ok, %{count: count}} when is_integer(count) -> count
      _ -> 0
    end
  end

  defp list_groups(:archived, opts), do: Communities.archived_groups(opts)
  defp list_groups(filter, opts), do: Communities.groups_for_actor(filter, opts)

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
        Logger.warning("GroupsLive load failed: #{inspect(reason)}")

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
        <div id="my-groups" class="grid">
          <.group_card :for={group <- @groups} group={group} role={group.viewer_role} />
        </div>
        <.pagination
          :if={@page_info.total_pages > 1}
          current_page={@page_info.current_page}
          total_pages={@page_info.total_pages}
          event_name="change_page"
        />
      <% end %>

      <section
        :if={@drop_ins_count > 0}
        id="dropped-in-groups"
        class="dropped-in"
        aria-labelledby="dropped-in-title"
      >
        <div class="dropped-in-head">
          <h2 id="dropped-in-title">Groups you've dropped in on</h2>
          <p>You've RSVPd to their huddlz without joining. Join to hear about their next ones.</p>
        </div>
        <div id="dropped-in-cards" class="grid" phx-update="stream">
          <.dropped_in_card
            :for={{dom_id, drop_in} <- @streams.drop_ins}
            id={dom_id}
            drop_in={drop_in}
          />
        </div>
        <.button
          :if={!@drop_ins_expanded? && @drop_ins_count > drop_ins_visible()}
          variant={:secondary}
          id="dropped-in-show-all"
          phx-click="show_all_dropped_in"
        >
          Show all {@drop_ins_count}
        </.button>
      </section>
    </Layouts.app>
    """
  end

  attr :drop_in, :map, required: true
  attr :id, :string, required: true

  # Not the shared `<.card>`: that one is a single link, and this card holds
  # two buttons. The name links to the group instead.
  defp dropped_in_card(assigns) do
    ~H"""
    <article id={@id} class="card dropped-in-card">
      <div class="card-cover">
        <.group_cover id={"dropped-in-cover-#{@drop_in.group.id}"} group={@drop_in.group} />
      </div>
      <div class="card-body">
        <span :if={@drop_in.group.location} class="card-group">{@drop_in.group.location}</span>
        <h3 class="card-title">
          <.link navigate={~p"/groups/#{@drop_in.group.slug}"}>{@drop_in.group.name}</.link>
        </h3>
        <div class="card-meta dropped-in-fact">
          <.icon name={spot_icon(@drop_in.spot)} class="size-4" />
          <span>{spot_line(@drop_in)}</span>
        </div>
      </div>
      <div class="card-foot dropped-in-actions">
        <.button
          variant={:secondary}
          phx-click="join_dropped_in"
          phx-value-group-id={@drop_in.group.id}
          phx-disable-with="Joining..."
        >
          Join group
        </.button>
        <.button
          variant={:muted}
          phx-click="dismiss_dropped_in"
          phx-value-group-id={@drop_in.group.id}
        >
          Not now
        </.button>
      </div>
    </article>
    """
  end

  defp drop_ins_visible, do: @drop_ins_visible

  # huddlz knows who RSVPd, not who came, so a finished huddl reads "RSVPd".
  defp spot_line(%{spot: :going, huddl: huddl}),
    do: "You're going to #{huddl.title} on #{huddl_day(huddl)}"

  defp spot_line(%{spot: :waitlisted, huddl: huddl}),
    do: "Waitlisted for #{huddl.title} on #{huddl_day(huddl)}"

  defp spot_line(%{spot: :rsvpd, huddl: huddl}),
    do: "You RSVPd to #{huddl.title} on #{huddl_day(huddl)}"

  defp spot_icon(:going), do: "hero-calendar"
  defp spot_icon(:waitlisted), do: "hero-clock"
  defp spot_icon(:rsvpd), do: "hero-check"

  defp huddl_day(huddl) do
    huddl |> HuddlCardHelpers.local_starts_at() |> Calendar.strftime("%b %-d")
  end

  attr :group, :map, required: true
  attr :role, :atom, required: true

  defp group_card(assigns) do
    ~H"""
    <.card navigate={~p"/groups/#{@group.slug}"}>
      <:cover>
        <.group_cover id={"group-list-cover-#{@group.id}"} group={@group} />
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
