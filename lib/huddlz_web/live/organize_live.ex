defmodule HuddlzWeb.OrganizeLive do
  @moduledoc """
  Organizer workspace shell. Sidebar tabs (Overview, Groups, Huddlz,
  Calendar, Attendees, Members, Settings) live at /organize and
  /organize/<tab>. Phase 3.1 ships the Overview tab with three metric tiles
  (Upcoming huddlz, Open RSVPs, Groups managed) plus quick actions; the
  rest are placeholder cards that link to the closest existing surface
  until later phases polish them. Drafts is deferred until both Huddl and
  Group gain a real draft state — see iteration-backlog.md §3.7.
  """
  use HuddlzWeb, :live_view

  import HuddlzWeb.OrganizeLive.Components

  require Ash.Query

  alias Huddlz.Communities.Group
  alias Huddlz.Communities.GroupMember
  alias Huddlz.Communities.Huddl
  alias Huddlz.Communities.HuddlAttendee
  alias Huddlz.Storage.GroupImages
  alias HuddlzWeb.Layouts

  @huddl_loads [:rsvp_count, :group]
  @overview_huddl_limit 100
  @attendees_huddl_loads [:rsvp_count, :waitlist_count, :group]
  @group_loads [:current_image_url, :member_count]
  @member_role_order [:owner, :organizer, :member]

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Organizer workspace")
     |> assign(:owned_groups, [])
     |> assign(:groups_list, [])
     |> assign(:huddlz_list, [])
     |> assign(:huddlz_filter, :live)
     |> assign(:upcoming_huddlz, [])
     |> assign(:upcoming_count, 0)
     |> assign(:open_rsvps, 0)
     |> assign(:attendees_huddlz, [])
     |> assign(:selected_huddl, nil)
     |> assign(:selected_attendees, [])
     |> assign(:selected_waitlist, [])
     |> assign(:members_groups, [])
     |> assign(:selected_group, nil)
     |> assign(:selected_members, [])}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    action = socket.assigns.live_action

    {:noreply,
     socket
     |> assign(:active, action)
     |> assign(:huddlz_filter, parse_huddlz_filter(params["filter"]))
     |> load_action(action, params, socket.assigns.current_user)}
  end

  defp load_action(socket, :overview, _params, user) do
    owned_groups = load_owned_groups(user)
    upcoming_huddlz = load_upcoming_huddlz(owned_groups, user)
    open_rsvps = Enum.reduce(upcoming_huddlz, 0, &(&1.rsvp_count + &2))

    socket
    |> assign(:owned_groups, owned_groups)
    |> assign(:upcoming_huddlz, upcoming_huddlz)
    |> assign(:upcoming_count, length(upcoming_huddlz))
    |> assign(:open_rsvps, open_rsvps)
  end

  defp load_action(socket, :groups, _params, user) do
    assign(socket, :groups_list, load_owned_groups(user))
  end

  defp load_action(socket, :huddlz, _params, user) do
    state = socket.assigns.huddlz_filter

    huddlz =
      Huddl
      |> Ash.Query.for_read(:huddlz_for_organizer, %{state: state}, actor: user)
      |> Ash.Query.load([:rsvp_count, :status, :group])
      |> Ash.Query.sort(starts_at: state_sort_dir(state))
      |> Ash.read!(actor: user)

    socket
    |> assign(:owned_groups, load_owned_groups(user))
    |> assign(:huddlz_list, huddlz)
  end

  defp load_action(socket, :attendees, params, user) do
    huddlz =
      Huddl
      |> Ash.Query.for_read(:huddlz_for_organizer, %{state: :live}, actor: user)
      |> Ash.Query.load(@attendees_huddl_loads)
      |> Ash.Query.sort(starts_at: :asc)
      |> Ash.read!(actor: user)

    selected = find_selected_huddl(huddlz, params["huddl"])

    socket
    |> assign(:attendees_huddlz, huddlz)
    |> assign(:selected_huddl, selected)
    |> assign(:selected_attendees, load_attendees(selected, user))
    |> assign(:selected_waitlist, load_waitlist(selected, user))
  end

  defp load_action(socket, :members, params, user) do
    groups = load_owned_groups(user)
    selected = find_selected_group(groups, params["group"])

    socket
    |> assign(:members_groups, groups)
    |> assign(:selected_group, selected)
    |> assign(:selected_members, load_group_members(selected, user))
  end

  defp load_action(socket, _, _params, _user), do: socket

  defp find_selected_huddl(_huddlz, nil), do: nil

  defp find_selected_huddl(huddlz, id) do
    Enum.find(huddlz, &(&1.id == id))
  end

  defp load_attendees(nil, _user), do: []

  defp load_attendees(huddl, user) do
    HuddlAttendee
    |> Ash.Query.for_read(:by_huddl, %{huddl_id: huddl.id}, actor: user)
    |> Ash.Query.load(:user)
    |> Ash.Query.sort(rsvped_at: :asc)
    |> Ash.read!(actor: user)
  end

  defp load_waitlist(nil, _user), do: []

  defp load_waitlist(huddl, user) do
    HuddlAttendee
    |> Ash.Query.for_read(:waitlist_for_huddl, %{huddl_id: huddl.id}, actor: user)
    |> Ash.Query.load(:user)
    |> Ash.read!(actor: user)
  end

  defp find_selected_group(_groups, nil), do: nil

  defp find_selected_group(groups, slug) do
    Enum.find(groups, &(&1.slug == slug))
  end

  defp load_group_members(nil, _user), do: []

  defp load_group_members(group, user) do
    GroupMember
    |> Ash.Query.for_read(:get_by_group, %{group_id: group.id}, actor: user)
    |> Ash.Query.load(:user)
    |> Ash.Query.sort(role: :asc, created_at: :asc)
    |> Ash.read!(actor: user)
  end

  defp parse_huddlz_filter("past"), do: :past
  defp parse_huddlz_filter(_), do: :live

  defp state_sort_dir(:past), do: :desc
  defp state_sort_dir(_), do: :asc

  defp load_owned_groups(user) do
    Group
    |> Ash.Query.for_read(:get_by_owner, %{}, actor: user)
    |> Ash.Query.load(@group_loads)
    |> Ash.Query.sort(name: :asc)
    |> Ash.read!(actor: user)
  end

  defp load_upcoming_huddlz([], _user), do: []

  defp load_upcoming_huddlz(owned_groups, user) do
    group_ids = Enum.map(owned_groups, & &1.id)

    Huddl
    |> Ash.Query.for_read(:upcoming, %{}, actor: user)
    |> Ash.Query.filter(group_id in ^group_ids)
    |> Ash.Query.limit(@overview_huddl_limit)
    |> Ash.Query.load(@huddl_loads)
    |> Ash.read!(actor: user)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.workspace_chrome active={@active} current_user={@current_user}>
        <%= case @active do %>
          <% :overview -> %>
            <.overview_tab
              owned_groups={@owned_groups}
              upcoming_huddlz={@upcoming_huddlz}
              upcoming_count={@upcoming_count}
              open_rsvps={@open_rsvps}
            />
          <% :groups -> %>
            <.groups_tab groups={@groups_list} />
          <% :huddlz -> %>
            <.huddlz_tab
              huddlz={@huddlz_list}
              filter={@huddlz_filter}
              owned_groups={@owned_groups}
            />
          <% :calendar -> %>
            <.placeholder_tab
              title="Calendar"
              description="Month, week, and agenda views across the groups you organize."
              phase="3.8"
              cta_label={nil}
              cta_path={nil}
            />
          <% :attendees -> %>
            <.attendees_tab
              huddlz={@attendees_huddlz}
              selected={@selected_huddl}
              attendees={@selected_attendees}
              waitlist={@selected_waitlist}
            />
          <% :members -> %>
            <.members_tab
              groups={@members_groups}
              selected={@selected_group}
              members={@selected_members}
            />
          <% :settings -> %>
            <.placeholder_tab
              title="Settings"
              description="Organizer defaults — visibility, RSVP windows, reminders, capacity, attendee questions."
              phase="3.9"
              cta_label={nil}
              cta_path={nil}
            />
        <% end %>
      </.workspace_chrome>
    </Layouts.app>
    """
  end

  @upcoming_preview_limit 5

  attr :owned_groups, :list, required: true
  attr :upcoming_huddlz, :list, required: true
  attr :upcoming_count, :integer, required: true
  attr :open_rsvps, :integer, required: true

  defp overview_tab(assigns) do
    assigns = assign(assigns, :preview_limit, @upcoming_preview_limit)

    ~H"""
    <header class="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
      <div>
        <span class="mono-label text-primary/70">// Overview</span>
        <h1 class="text-3xl font-extrabold tracking-tight text-base-content mt-2">
          Organizer workspace.
        </h1>
        <p class="mt-2 text-base-content/60 max-w-2xl">
          A scannable summary of the huddlz and groups you run.
        </p>
      </div>
      <div class="flex flex-wrap gap-2">
        <.button navigate={~p"/groups/new"}>Create group</.button>
        <.button variant="primary" navigate={create_huddl_path(@owned_groups)}>
          Create huddl
        </.button>
      </div>
    </header>

    <%= if @owned_groups == [] do %>
      <.empty_state />
    <% else %>
      <section class="grid gap-4 sm:grid-cols-3" aria-label="Workspace metrics">
        <.metric_tile label="Upcoming huddlz" value={@upcoming_count} />
        <.metric_tile label="Open RSVPs" value={@open_rsvps} />
        <.metric_tile label="Groups managed" value={length(@owned_groups)} />
      </section>

      <section>
        <div class="flex items-baseline justify-between gap-2">
          <h2 class="text-lg font-extrabold tracking-tight text-base-content flex items-baseline gap-3">
            <span class="mono-label text-primary/70">// Upcoming huddlz</span>
            <span class="text-sm font-body font-normal text-base-content/40">
              ({@upcoming_count})
            </span>
          </h2>
          <.link
            :if={@upcoming_count > @preview_limit}
            navigate={~p"/organize/huddlz"}
            class="text-xs font-bold text-primary hover:underline"
          >
            View all →
          </.link>
        </div>

        <%= if @upcoming_huddlz == [] do %>
          <div class="border border-dashed border-base-300 p-8 mt-4 text-center text-base-content/50">
            No upcoming huddlz right now. Create one to get started.
          </div>
        <% else %>
          <ul class="mt-4 divide-y divide-base-300 border border-base-300">
            <%= for huddl <- Enum.take(@upcoming_huddlz, @preview_limit) do %>
              <li class="flex items-center justify-between gap-4 px-5 py-4">
                <div class="min-w-0">
                  <.link
                    navigate={~p"/groups/#{huddl.group.slug}/huddlz/#{huddl.id}"}
                    class="text-base font-extrabold tracking-tight text-base-content hover:text-primary transition-colors block truncate"
                  >
                    {huddl.title}
                  </.link>
                  <p class="text-xs text-base-content/60 mt-1 flex flex-wrap items-center gap-x-3 gap-y-1">
                    <span>{format_starts_at(huddl.starts_at)}</span>
                    <span class="text-base-content/30">·</span>
                    <span>{huddl.group.name}</span>
                  </p>
                </div>
                <.huddl_badge variant="cyan" class="flex-shrink-0">
                  {rsvp_label(huddl.rsvp_count)}
                </.huddl_badge>
              </li>
            <% end %>
          </ul>
        <% end %>
      </section>
    <% end %>
    """
  end

  attr :label, :string, required: true
  attr :value, :integer, required: true

  defp metric_tile(assigns) do
    ~H"""
    <div class="border border-base-300 p-6">
      <span class="mono-label text-primary/70">// {@label}</span>
      <p class="text-3xl font-extrabold tracking-tight text-base-content mt-2">{@value}</p>
    </div>
    """
  end

  defp empty_state(assigns) do
    ~H"""
    <div class="border border-base-300 p-8">
      <span class="mono-label text-primary/70">// Get started</span>
      <h2 class="text-xl font-extrabold tracking-tight text-base-content mt-2">
        You don't organize any groups yet.
      </h2>
      <p class="mt-2 text-sm text-base-content/60 max-w-xl">
        Create a group to start hosting huddlz. Once you have a group, this overview will fill in with upcoming huddlz, RSVP totals, and quick actions.
      </p>
      <.button variant="primary" navigate={~p"/groups/new"} class="mt-4">
        Create your first group
      </.button>
    </div>
    """
  end

  attr :groups, :list, required: true

  defp groups_tab(assigns) do
    ~H"""
    <header class="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
      <div>
        <span class="mono-label text-primary/70">// Groups</span>
        <h1 class="text-3xl font-extrabold tracking-tight text-base-content mt-2">
          Manage your groups.
        </h1>
        <p class="mt-2 text-base-content/60 max-w-2xl">
          Communities where you have organizer permissions. Click a row to edit its profile, image, and visibility.
        </p>
      </div>
      <.button variant="primary" navigate={~p"/groups/new"}>Create group</.button>
    </header>

    <%= if @groups == [] do %>
      <div class="border border-base-300 p-8">
        <span class="mono-label text-primary/70">// No groups yet</span>
        <h2 class="text-xl font-extrabold tracking-tight text-base-content mt-2">
          You don't organize any groups yet.
        </h2>
        <p class="mt-2 text-sm text-base-content/60 max-w-xl">
          Create a group to start hosting huddlz. Each group can have its own members, organizers, and recurring or one-off huddlz.
        </p>
        <.button variant="primary" navigate={~p"/groups/new"} class="mt-4">
          Create your first group
        </.button>
      </div>
    <% else %>
      <section>
        <div class="flex items-baseline justify-between gap-2">
          <h2 class="text-lg font-extrabold tracking-tight text-base-content flex items-baseline gap-3">
            <span class="mono-label text-primary/70">// Groups you organize</span>
            <span class="text-sm font-body font-normal text-base-content/40">
              ({length(@groups)})
            </span>
          </h2>
        </div>

        <ul class="mt-4 divide-y divide-base-300 border border-base-300">
          <%= for group <- @groups do %>
            <.group_row group={group} />
          <% end %>
        </ul>
      </section>
    <% end %>
    """
  end

  attr :group, :map, required: true

  defp group_row(assigns) do
    ~H"""
    <li>
      <.link
        navigate={~p"/groups/#{@group.slug}/edit"}
        class="flex items-center gap-4 px-5 py-4 hover:bg-base-200/40 transition-colors group"
      >
        <div class="w-20 aspect-video flex-shrink-0 overflow-hidden border border-base-300 bg-base-300">
          <%= if @group.current_image_url do %>
            <img
              src={GroupImages.url(@group.current_image_url)}
              alt={@group.name}
              class="w-full h-full object-cover"
            />
          <% else %>
            <div class="w-full h-full bg-base-100 flex items-center justify-center">
              <span class="text-[10px] font-extrabold text-base-content/30 text-center px-1 line-clamp-2">
                {@group.name}
              </span>
            </div>
          <% end %>
        </div>

        <div class="flex-1 min-w-0">
          <h3 class="text-base font-extrabold tracking-tight text-base-content group-hover:text-primary transition-colors truncate">
            {@group.name}
          </h3>
          <p class="text-xs text-base-content/60 mt-1 flex flex-wrap items-center gap-x-3 gap-y-1">
            <span>{member_label(@group.member_count)}</span>
            <span :if={@group.location} class="text-base-content/30">·</span>
            <span :if={@group.location}>{@group.location}</span>
          </p>
        </div>

        <.huddl_badge variant={visibility_variant(@group.is_public)} class="flex-shrink-0">
          {visibility_label(@group.is_public)}
        </.huddl_badge>

        <.icon
          name="hero-chevron-right"
          class="w-4 h-4 text-base-content/40 group-hover:text-primary transition-colors flex-shrink-0"
        />
      </.link>
    </li>
    """
  end

  attr :huddlz, :list, required: true
  attr :filter, :atom, required: true
  attr :owned_groups, :list, required: true

  defp huddlz_tab(assigns) do
    ~H"""
    <header class="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
      <div>
        <span class="mono-label text-primary/70">// Huddlz</span>
        <h1 class="text-3xl font-extrabold tracking-tight text-base-content mt-2">
          Manage your huddlz.
        </h1>
        <p class="mt-2 text-base-content/60 max-w-2xl">
          Every huddl across the groups you organize. Click a row to edit details, location, and capacity.
        </p>
      </div>
      <.button variant="primary" navigate={create_huddl_path(@owned_groups)}>Create huddl</.button>
    </header>

    <nav class="flex gap-2" aria-label="Huddlz filter">
      <.filter_chip label="Live" active={@filter == :live} path={~p"/organize/huddlz"} />
      <.filter_chip label="Past" active={@filter == :past} path={~p"/organize/huddlz?filter=past"} />
    </nav>

    <%= if @huddlz == [] do %>
      <.huddlz_empty filter={@filter} owned_groups={@owned_groups} />
    <% else %>
      <section>
        <div class="flex items-baseline justify-between gap-2">
          <h2 class="text-lg font-extrabold tracking-tight text-base-content flex items-baseline gap-3">
            <span class="mono-label text-primary/70">// {filter_eyebrow(@filter)}</span>
            <span class="text-sm font-body font-normal text-base-content/40">
              ({length(@huddlz)})
            </span>
          </h2>
        </div>

        <ul class="mt-4 divide-y divide-base-300 border border-base-300">
          <%= for huddl <- @huddlz do %>
            <.huddl_row huddl={huddl} />
          <% end %>
        </ul>
      </section>
    <% end %>
    """
  end

  attr :huddl, :map, required: true

  defp huddl_row(assigns) do
    ~H"""
    <li>
      <.link
        navigate={~p"/groups/#{@huddl.group.slug}/huddlz/#{@huddl.id}/edit"}
        class="flex items-center gap-4 px-5 py-4 hover:bg-base-200/40 transition-colors group"
      >
        <div class="flex-1 min-w-0">
          <h3 class="text-base font-extrabold tracking-tight text-base-content group-hover:text-primary transition-colors truncate">
            {@huddl.title}
          </h3>
          <p class="text-xs text-base-content/60 mt-1 flex flex-wrap items-center gap-x-3 gap-y-1">
            <span>{format_starts_at(@huddl.starts_at)}</span>
            <span class="text-base-content/30">·</span>
            <span class="truncate">{@huddl.group.name}</span>
          </p>
        </div>

        <.huddl_badge variant="cyan" class="flex-shrink-0">
          {rsvp_label(@huddl.rsvp_count)}
        </.huddl_badge>

        <.huddl_status_badge status={@huddl.status} class="flex-shrink-0" />

        <.icon
          name="hero-chevron-right"
          class="w-4 h-4 text-base-content/40 group-hover:text-primary transition-colors flex-shrink-0"
        />
      </.link>
    </li>
    """
  end

  attr :label, :string, required: true
  attr :active, :boolean, required: true
  attr :path, :string, required: true

  defp filter_chip(assigns) do
    ~H"""
    <.link
      patch={@path}
      class={[
        "inline-flex items-center gap-2 px-3 py-1.5 text-xs font-extrabold uppercase tracking-wider border transition-colors",
        @active && "border-primary text-primary bg-primary/10",
        !@active &&
          "border-base-300 text-base-content/60 hover:text-base-content hover:border-base-content/40"
      ]}
    >
      {@label}
    </.link>
    """
  end

  attr :filter, :atom, required: true
  attr :owned_groups, :list, required: true

  defp huddlz_empty(assigns) do
    ~H"""
    <div class="border border-base-300 p-8">
      <span class="mono-label text-primary/70">// {empty_eyebrow(@filter)}</span>
      <h2 class="text-xl font-extrabold tracking-tight text-base-content mt-2">
        {empty_heading(@filter)}
      </h2>
      <p class="mt-2 text-sm text-base-content/60 max-w-xl">
        {empty_body(@filter)}
      </p>
      <.button
        :if={@filter == :live}
        variant="primary"
        navigate={create_huddl_path(@owned_groups)}
        class="mt-4"
      >
        Create your first huddl
      </.button>
    </div>
    """
  end

  attr :huddlz, :list, required: true
  attr :selected, :any, required: true
  attr :attendees, :list, required: true
  attr :waitlist, :list, required: true

  defp attendees_tab(assigns) do
    ~H"""
    <header class="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
      <div>
        <span class="mono-label text-primary/70">// Attendees</span>
        <h1 class="text-3xl font-extrabold tracking-tight text-base-content mt-2">
          Track attendees.
        </h1>
        <p class="mt-2 text-base-content/60 max-w-2xl">
          RSVPs and waitlist for every upcoming huddl across the groups you organize.
          Click a huddl to see who is coming.
        </p>
      </div>
    </header>

    <%= if @selected do %>
      <.attendees_detail
        huddl={@selected}
        attendees={@attendees}
        waitlist={@waitlist}
      />
    <% else %>
      <.attendees_index huddlz={@huddlz} />
    <% end %>
    """
  end

  attr :huddlz, :list, required: true

  defp attendees_index(assigns) do
    ~H"""
    <%= if @huddlz == [] do %>
      <div class="border border-base-300 p-8">
        <span class="mono-label text-primary/70">// No upcoming huddlz</span>
        <h2 class="text-xl font-extrabold tracking-tight text-base-content mt-2">
          Nothing on the calendar.
        </h2>
        <p class="mt-2 text-sm text-base-content/60 max-w-xl">
          When you publish a huddl, it'll appear here so you can review RSVPs and waitlist
          activity at a glance.
        </p>
      </div>
    <% else %>
      <section>
        <div class="flex items-baseline justify-between gap-2">
          <h2 class="text-lg font-extrabold tracking-tight text-base-content flex items-baseline gap-3">
            <span class="mono-label text-primary/70">// Upcoming huddlz</span>
            <span class="text-sm font-body font-normal text-base-content/40">
              ({length(@huddlz)})
            </span>
          </h2>
        </div>

        <ul class="mt-4 divide-y divide-base-300 border border-base-300">
          <%= for huddl <- @huddlz do %>
            <.attendees_index_row huddl={huddl} />
          <% end %>
        </ul>
      </section>
    <% end %>
    """
  end

  attr :huddl, :map, required: true

  defp attendees_index_row(assigns) do
    ~H"""
    <li>
      <.link
        patch={~p"/organize/attendees?#{[huddl: @huddl.id]}"}
        class="flex items-center gap-4 px-5 py-4 hover:bg-base-200/40 transition-colors group"
      >
        <div class="flex-1 min-w-0">
          <h3 class="text-base font-extrabold tracking-tight text-base-content group-hover:text-primary transition-colors truncate">
            {@huddl.title}
          </h3>
          <p class="text-xs text-base-content/60 mt-1 flex flex-wrap items-center gap-x-3 gap-y-1">
            <span>{format_starts_at(@huddl.starts_at)}</span>
            <span class="text-base-content/30">·</span>
            <span class="truncate">{@huddl.group.name}</span>
          </p>
        </div>

        <.huddl_badge variant="cyan" class="flex-shrink-0">
          {rsvp_label(@huddl.rsvp_count)}
        </.huddl_badge>

        <.huddl_badge variant="outline" class="flex-shrink-0">
          {waitlist_label(@huddl.waitlist_count)}
        </.huddl_badge>

        <.icon
          name="hero-chevron-right"
          class="w-4 h-4 text-base-content/40 group-hover:text-primary transition-colors flex-shrink-0"
        />
      </.link>
    </li>
    """
  end

  attr :huddl, :map, required: true
  attr :attendees, :list, required: true
  attr :waitlist, :list, required: true

  defp attendees_detail(assigns) do
    ~H"""
    <section class="space-y-6">
      <div class="flex flex-wrap items-baseline justify-between gap-3">
        <div class="min-w-0">
          <.link
            patch={~p"/organize/attendees"}
            class="inline-flex items-center gap-1 text-xs font-bold text-primary hover:underline"
          >
            <.icon name="hero-chevron-left" class="w-3 h-3" /> All upcoming
          </.link>
          <h2 class="mt-2 text-2xl font-extrabold tracking-tight text-base-content truncate">
            {@huddl.title}
          </h2>
          <p class="mt-1 text-xs text-base-content/60 flex flex-wrap items-center gap-x-3 gap-y-1">
            <span>{format_starts_at(@huddl.starts_at)}</span>
            <span class="text-base-content/30">·</span>
            <span class="truncate">{@huddl.group.name}</span>
          </p>
        </div>
        <.link
          navigate={~p"/groups/#{@huddl.group.slug}/huddlz/#{@huddl.id}/edit"}
          class="text-xs font-bold text-primary hover:underline"
        >
          Edit huddl →
        </.link>
      </div>

      <div class="grid gap-6 lg:grid-cols-2">
        <.attendee_panel
          eyebrow="// Attending"
          heading="RSVPed"
          empty_copy="Nobody has RSVPed yet."
          rows={@attendees}
          show_position={false}
        />
        <.attendee_panel
          eyebrow="// Waitlist"
          heading="Waitlist"
          empty_copy="Nobody is on the waitlist."
          rows={@waitlist}
          show_position={true}
        />
      </div>
    </section>
    """
  end

  attr :eyebrow, :string, required: true
  attr :heading, :string, required: true
  attr :empty_copy, :string, required: true
  attr :rows, :list, required: true
  attr :show_position, :boolean, required: true

  defp attendee_panel(assigns) do
    ~H"""
    <div class="border border-base-300">
      <div class="border-b border-base-300 px-5 py-4 flex items-baseline gap-3">
        <span class="mono-label text-primary/70">{@eyebrow}</span>
        <p class="text-base font-extrabold tracking-tight text-base-content">{@heading}</p>
        <span class="text-sm font-body font-normal text-base-content/40">
          ({length(@rows)})
        </span>
      </div>

      <%= if @rows == [] do %>
        <p class="px-5 py-6 text-sm text-base-content/50">{@empty_copy}</p>
      <% else %>
        <ul class="divide-y divide-base-300">
          <%= for {entry, index} <- Enum.with_index(@rows, 1) do %>
            <li class="flex items-center gap-3 px-5 py-3">
              <span
                :if={@show_position}
                class="mono-label text-base-content/40 w-6 flex-shrink-0"
              >
                {index}
              </span>
              <div class="min-w-0 flex-1">
                <p class="text-sm font-bold text-base-content truncate">
                  {attendee_name(entry)}
                </p>
                <p class="text-xs text-base-content/50 mt-0.5">
                  {format_attendee_meta(entry)}
                </p>
              </div>
            </li>
          <% end %>
        </ul>
      <% end %>
    </div>
    """
  end

  attr :groups, :list, required: true
  attr :selected, :any, required: true
  attr :members, :list, required: true

  defp members_tab(assigns) do
    ~H"""
    <header class="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
      <div>
        <span class="mono-label text-primary/70">// Members</span>
        <h1 class="text-3xl font-extrabold tracking-tight text-base-content mt-2">
          Understand members.
        </h1>
        <p class="mt-2 text-base-content/60 max-w-2xl">
          The people connected to the groups you own. Click a group to see its roster
          by role.
        </p>
      </div>
    </header>

    <%= if @selected do %>
      <.members_detail group={@selected} members={@members} />
    <% else %>
      <.members_index groups={@groups} />
    <% end %>
    """
  end

  attr :groups, :list, required: true

  defp members_index(assigns) do
    ~H"""
    <%= if @groups == [] do %>
      <div class="border border-base-300 p-8">
        <span class="mono-label text-primary/70">// No groups yet</span>
        <h2 class="text-xl font-extrabold tracking-tight text-base-content mt-2">
          You don't own any groups yet.
        </h2>
        <p class="mt-2 text-sm text-base-content/60 max-w-xl">
          Create a group to start building a community. Once you have one, this tab
          shows the people who joined it.
        </p>
        <.button variant="primary" navigate={~p"/groups/new"} class="mt-4">
          Create your first group
        </.button>
      </div>
    <% else %>
      <section>
        <div class="flex items-baseline justify-between gap-2">
          <h2 class="text-lg font-extrabold tracking-tight text-base-content flex items-baseline gap-3">
            <span class="mono-label text-primary/70">// Your groups</span>
            <span class="text-sm font-body font-normal text-base-content/40">
              ({length(@groups)})
            </span>
          </h2>
        </div>

        <ul class="mt-4 divide-y divide-base-300 border border-base-300">
          <%= for group <- @groups do %>
            <.members_index_row group={group} />
          <% end %>
        </ul>
      </section>
    <% end %>
    """
  end

  attr :group, :map, required: true

  defp members_index_row(assigns) do
    ~H"""
    <li>
      <.link
        patch={~p"/organize/members?#{[group: @group.slug]}"}
        class="flex items-center gap-4 px-5 py-4 hover:bg-base-200/40 transition-colors group"
      >
        <div class="flex-1 min-w-0">
          <h3 class="text-base font-extrabold tracking-tight text-base-content group-hover:text-primary transition-colors truncate">
            {@group.name}
          </h3>
          <p class="text-xs text-base-content/60 mt-1 flex flex-wrap items-center gap-x-3 gap-y-1">
            <span>{member_label(@group.member_count)}</span>
            <span :if={@group.location} class="text-base-content/30">·</span>
            <span :if={@group.location}>{@group.location}</span>
          </p>
        </div>

        <.huddl_badge variant={visibility_variant(@group.is_public)} class="flex-shrink-0">
          {visibility_label(@group.is_public)}
        </.huddl_badge>

        <.icon
          name="hero-chevron-right"
          class="w-4 h-4 text-base-content/40 group-hover:text-primary transition-colors flex-shrink-0"
        />
      </.link>
    </li>
    """
  end

  attr :group, :map, required: true
  attr :members, :list, required: true

  defp members_detail(assigns) do
    grouped =
      @member_role_order
      |> Enum.map(fn role -> {role, Enum.filter(assigns.members, &(&1.role == role))} end)

    assigns = assign(assigns, :grouped, grouped)

    ~H"""
    <section class="space-y-6">
      <div class="flex flex-wrap items-baseline justify-between gap-3">
        <div class="min-w-0">
          <.link
            patch={~p"/organize/members"}
            class="inline-flex items-center gap-1 text-xs font-bold text-primary hover:underline"
          >
            <.icon name="hero-chevron-left" class="w-3 h-3" /> All groups
          </.link>
          <h2 class="mt-2 text-2xl font-extrabold tracking-tight text-base-content truncate">
            {@group.name}
          </h2>
          <p class="mt-1 text-xs text-base-content/60 flex flex-wrap items-center gap-x-3 gap-y-1">
            <span>{member_label(@group.member_count)}</span>
            <span :if={@group.location} class="text-base-content/30">·</span>
            <span :if={@group.location}>{@group.location}</span>
          </p>
        </div>
        <.link
          navigate={~p"/groups/#{@group.slug}/edit"}
          class="text-xs font-bold text-primary hover:underline"
        >
          Edit group →
        </.link>
      </div>

      <div class="space-y-6">
        <%= for {role, rows} <- @grouped do %>
          <.member_panel role={role} rows={rows} />
        <% end %>
      </div>

      <p class="text-xs text-base-content/40 max-w-xl">
        Role changes and removals are not yet wired into the workspace. Use the existing
        group tools when those operations land in a follow-up.
      </p>
    </section>
    """
  end

  attr :role, :atom, required: true
  attr :rows, :list, required: true

  defp member_panel(assigns) do
    ~H"""
    <div class="border border-base-300">
      <div class="border-b border-base-300 px-5 py-4 flex items-baseline gap-3">
        <span class="mono-label text-primary/70">// {role_eyebrow(@role)}</span>
        <p class="text-base font-extrabold tracking-tight text-base-content">
          {role_heading(@role)}
        </p>
        <span class="text-sm font-body font-normal text-base-content/40">
          ({length(@rows)})
        </span>
      </div>

      <%= if @rows == [] do %>
        <p class="px-5 py-6 text-sm text-base-content/50">{role_empty_copy(@role)}</p>
      <% else %>
        <ul class="divide-y divide-base-300">
          <%= for entry <- @rows do %>
            <li class="flex items-center gap-3 px-5 py-3">
              <div class="min-w-0 flex-1">
                <p class="text-sm font-bold text-base-content truncate">
                  {member_name(entry)}
                </p>
                <p class="text-xs text-base-content/50 mt-0.5">
                  {format_member_meta(entry)}
                </p>
              </div>
              <.huddl_badge variant={role_badge_variant(@role)} class="flex-shrink-0">
                {role_label(@role)}
              </.huddl_badge>
            </li>
          <% end %>
        </ul>
      <% end %>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :phase, :string, required: true
  attr :cta_label, :any, default: nil
  attr :cta_path, :any, default: nil

  defp placeholder_tab(assigns) do
    ~H"""
    <header>
      <span class="mono-label text-primary/70">// {@title}</span>
      <h1 class="text-3xl font-extrabold tracking-tight text-base-content mt-2">{@title}.</h1>
      <p class="mt-2 text-base-content/60 max-w-2xl">{@description}</p>
    </header>

    <div class="border border-base-300 p-8">
      <span class="mono-label text-primary/70">// Coming in Phase {@phase}</span>
      <p class="text-sm text-base-content/60 mt-3 max-w-xl">
        This tab will land in a follow-up ticket. Until then, use the link below for the closest existing surface.
      </p>
      <.link
        :if={@cta_path}
        navigate={@cta_path}
        class="mt-4 inline-flex text-xs font-bold text-primary hover:underline"
      >
        {@cta_label} →
      </.link>
      <p :if={!@cta_path} class="mt-4 text-xs font-bold text-base-content/40">
        No replacement surface available yet.
      </p>
    </div>
    """
  end

  defp create_huddl_path(_owned_groups), do: ~p"/organize/huddlz/new"

  defp rsvp_label(0), do: "0 RSVPs"
  defp rsvp_label(1), do: "1 RSVP"
  defp rsvp_label(n), do: "#{n} RSVPs"

  defp waitlist_label(0), do: "0 waitlist"
  defp waitlist_label(n), do: "#{n} waitlist"

  defp attendee_name(%{user: %{display_name: name}}) when is_binary(name) and name != "", do: name

  defp attendee_name(%{user: %{email: email}}) when not is_nil(email),
    do: to_string(email)

  defp attendee_name(_), do: "Unknown member"

  defp member_name(entry), do: attendee_name(entry)

  defp format_member_meta(%{created_at: %DateTime{} = at}), do: "Joined " <> format_relative(at)

  defp format_member_meta(%{created_at: %NaiveDateTime{} = at}) do
    "Joined " <> Calendar.strftime(at, "%b %d, %Y")
  end

  defp format_member_meta(_), do: ""

  defp role_eyebrow(:owner), do: "Owner"
  defp role_eyebrow(:organizer), do: "Organizers"
  defp role_eyebrow(:member), do: "Members"

  defp role_heading(:owner), do: "Group owner"
  defp role_heading(:organizer), do: "Organizers"
  defp role_heading(:member), do: "Members"

  defp role_label(:owner), do: "Owner"
  defp role_label(:organizer), do: "Organizer"
  defp role_label(:member), do: "Member"

  defp role_badge_variant(:owner), do: "cyan"
  defp role_badge_variant(:organizer), do: "outline"
  defp role_badge_variant(:member), do: "default"

  defp role_empty_copy(:owner), do: "No owner on file."

  defp role_empty_copy(:organizer),
    do: "No co-organizers yet. Promote a member to organizer to share the load."

  defp role_empty_copy(:member), do: "Nobody has joined yet."

  defp format_attendee_meta(%{waitlisted_at: %DateTime{} = at}),
    do: "Joined waitlist " <> format_relative(at)

  defp format_attendee_meta(%{rsvped_at: %DateTime{} = at}),
    do: "RSVPed " <> format_relative(at)

  defp format_attendee_meta(_), do: ""

  defp format_relative(%DateTime{} = at) do
    Calendar.strftime(at, "%b %d, %Y")
  end

  defp member_label(0), do: "No members yet"
  defp member_label(1), do: "1 member"
  defp member_label(n), do: "#{n} members"

  defp visibility_label(true), do: "Public"
  defp visibility_label(false), do: "Private"

  defp visibility_variant(true), do: "cyan"
  defp visibility_variant(false), do: "outline"

  defp filter_eyebrow(:past), do: "Past huddlz"
  defp filter_eyebrow(_), do: "Live huddlz"

  defp empty_eyebrow(:past), do: "No past huddlz"
  defp empty_eyebrow(_), do: "No live huddlz"

  defp empty_heading(:past), do: "No past huddlz yet."
  defp empty_heading(_), do: "Nothing on the calendar."

  defp empty_body(:past),
    do: "Once a huddl wraps up, it'll show up here so you can revisit attendance and notes."

  defp empty_body(_),
    do:
      "Schedule a huddl to start hosting. You'll see every active huddl across your groups in this list."

  defp format_starts_at(%DateTime{} = dt) do
    Calendar.strftime(dt, "%b %d, %Y · %I:%M %p")
  end

  defp format_starts_at(_), do: ""
end
