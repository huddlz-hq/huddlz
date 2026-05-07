defmodule HuddlzWeb.OrganizeLive do
  @moduledoc """
  Organizer workspace shell. Eight sidebar tabs (Overview, Groups, Huddlz,
  Calendar, Drafts, Attendees, Members, Settings) live at /organize and
  /organize/<tab>. Phase 3.1 ships the Overview tab with three metric tiles
  (Upcoming huddlz, Open RSVPs, Groups managed) plus quick actions; the
  rest are placeholder cards that link to the closest existing surface
  until later phases polish them.
  """
  use HuddlzWeb, :live_view

  require Ash.Query

  alias Huddlz.Communities
  alias Huddlz.Communities.Huddl
  alias HuddlzWeb.Layouts

  @huddl_loads [:rsvp_count, :group]
  @overview_huddl_limit 100

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Organizer workspace")
     |> assign(:owned_groups, [])
     |> assign(:upcoming_huddlz, [])
     |> assign(:upcoming_count, 0)
     |> assign(:open_rsvps, 0)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    action = socket.assigns.live_action

    {:noreply,
     socket
     |> assign(:active, action)
     |> load_action(action, socket.assigns.current_user)}
  end

  defp load_action(socket, :overview, user) do
    owned_groups =
      case Communities.get_by_owner(actor: user) do
        {:ok, groups} -> groups
        _ -> []
      end

    upcoming_huddlz = load_upcoming_huddlz(owned_groups, user)
    open_rsvps = Enum.reduce(upcoming_huddlz, 0, &(&1.rsvp_count + &2))

    socket
    |> assign(:owned_groups, owned_groups)
    |> assign(:upcoming_huddlz, upcoming_huddlz)
    |> assign(:upcoming_count, length(upcoming_huddlz))
    |> assign(:open_rsvps, open_rsvps)
  end

  defp load_action(socket, _, _user), do: socket

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
      <div class="grid grid-cols-1 lg:grid-cols-[260px_minmax(0,1fr)] gap-6 lg:gap-10">
        <.workspace_sidebar active={@active} current_user={@current_user} />

        <div class="space-y-10 min-w-0">
          <%= case @active do %>
            <% :overview -> %>
              <.overview_tab
                owned_groups={@owned_groups}
                upcoming_huddlz={@upcoming_huddlz}
                upcoming_count={@upcoming_count}
                open_rsvps={@open_rsvps}
              />
            <% :groups -> %>
              <.placeholder_tab
                title="Groups"
                description="Manage every group you organize from one cross-group list."
                phase="3.2"
                cta_label="Open hosting groups on /me"
                cta_path={~p"/me?#{[tab: :groups]}"}
              />
            <% :huddlz -> %>
              <.placeholder_tab
                title="Huddlz"
                description="Cross-group huddl list with Live, Draft, and Past filters."
                phase="3.3"
                cta_label="Browse groups"
                cta_path={~p"/groups"}
              />
            <% :calendar -> %>
              <.placeholder_tab
                title="Calendar"
                description="Month, week, and agenda views across the groups you organize."
                phase="3.8"
                cta_label={nil}
                cta_path={nil}
              />
            <% :drafts -> %>
              <.placeholder_tab
                title="Drafts"
                description="Unfinished groups and huddlz with completion checklists."
                phase="3.7"
                cta_label={nil}
                cta_path={nil}
              />
            <% :attendees -> %>
              <.placeholder_tab
                title="Attendees"
                description="Cross-huddl RSVP operations with a detail panel."
                phase="3.5"
                cta_label="Open hosting groups on /me"
                cta_path={~p"/me?#{[tab: :groups]}"}
              />
            <% :members -> %>
              <.placeholder_tab
                title="Members"
                description="Group membership operations across every group you organize."
                phase="3.6"
                cta_label="Open hosting groups on /me"
                cta_path={~p"/me?#{[tab: :groups]}"}
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
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :active, :atom, required: true
  attr :current_user, :map, required: true

  defp workspace_sidebar(assigns) do
    ~H"""
    <aside class="border border-base-300 self-start lg:sticky lg:top-28">
      <div class="border-b border-base-300 px-5 py-4">
        <span class="mono-label text-primary/70">// Workspace</span>
        <p class="font-display text-base tracking-tight text-glow mt-1">Organizer</p>
        <p class="text-xs text-base-content/50 mt-1">
          Operations across your groups and huddlz.
        </p>
      </div>

      <nav class="p-3 flex flex-col gap-1.5" aria-label="Organizer workspace tabs">
        <.sidebar_link active={@active} action={:overview} label="Overview" path={~p"/organize"} />
        <.sidebar_link
          active={@active}
          action={:groups}
          label="Groups"
          path={~p"/organize/groups"}
        />
        <.sidebar_link
          active={@active}
          action={:huddlz}
          label="Huddlz"
          path={~p"/organize/huddlz"}
        />
        <.sidebar_link
          active={@active}
          action={:calendar}
          label="Calendar"
          path={~p"/organize/calendar"}
        />
        <.sidebar_link
          active={@active}
          action={:drafts}
          label="Drafts"
          path={~p"/organize/drafts"}
        />
        <.sidebar_link
          active={@active}
          action={:attendees}
          label="Attendees"
          path={~p"/organize/attendees"}
        />
        <.sidebar_link
          active={@active}
          action={:members}
          label="Members"
          path={~p"/organize/members"}
        />
        <.sidebar_link
          active={@active}
          action={:settings}
          label="Settings"
          path={~p"/organize/settings"}
        />
      </nav>

      <div class="border-t border-base-300 px-5 py-3 text-xs text-base-content/50">
        Signed in as
        <span class="text-base-content/80 font-bold block truncate">
          {@current_user.display_name || @current_user.email}
        </span>
      </div>
    </aside>
    """
  end

  attr :active, :atom, required: true
  attr :action, :atom, required: true
  attr :label, :string, required: true
  attr :path, :string, required: true

  defp sidebar_link(assigns) do
    ~H"""
    <.link navigate={@path} class={sidebar_link_class(@active == @action)}>
      {@label}
    </.link>
    """
  end

  defp sidebar_link_class(true) do
    "block px-3 py-2 text-sm font-bold border border-primary bg-primary/10 text-primary"
  end

  defp sidebar_link_class(false) do
    "block px-3 py-2 text-sm font-bold border border-transparent text-base-content/80 hover:border-base-300 hover:text-primary transition-colors"
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
        <h1 class="font-display text-3xl tracking-tight text-glow mt-2">
          Organizer workspace.
        </h1>
        <p class="mt-2 text-base-content/60 max-w-2xl">
          A scannable summary of the huddlz and groups you run.
        </p>
      </div>
      <div class="flex flex-wrap gap-2">
        <.link
          navigate={~p"/groups/new"}
          class="inline-flex items-center min-h-10 px-4 text-sm font-bold border border-base-300 hover:border-primary hover:text-primary transition-colors"
        >
          Create group
        </.link>
        <.link
          navigate={create_huddl_path(@owned_groups)}
          class="inline-flex items-center min-h-10 px-4 text-sm font-bold bg-primary text-primary-content border border-primary btn-neon"
        >
          Create huddl
        </.link>
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
          <h2 class="font-display text-lg tracking-tight text-glow flex items-baseline gap-3">
            <span class="mono-label text-primary/70">// Upcoming huddlz</span>
            <span class="text-sm font-body font-normal text-base-content/40">
              ({@upcoming_count})
            </span>
          </h2>
          <.link
            :if={@upcoming_count > @preview_limit}
            navigate={~p"/organize/huddlz"}
            class="text-xs text-primary hover:underline font-medium tracking-wide uppercase"
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
                    class="font-display text-base tracking-tight hover:text-primary transition-colors block truncate"
                  >
                    {huddl.title}
                  </.link>
                  <p class="text-xs text-base-content/60 mt-1 flex flex-wrap items-center gap-x-3 gap-y-1">
                    <span>{format_starts_at(huddl.starts_at)}</span>
                    <span class="text-base-content/30">·</span>
                    <span>{huddl.group.name}</span>
                  </p>
                </div>
                <span class="text-xs text-primary/80 font-bold tracking-wide flex-shrink-0">
                  {rsvp_label(huddl.rsvp_count)}
                </span>
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
      <p class="font-display text-3xl tracking-tight text-glow mt-2">{@value}</p>
    </div>
    """
  end

  defp empty_state(assigns) do
    ~H"""
    <div class="border border-base-300 p-8">
      <span class="mono-label text-primary/70">// Get started</span>
      <h2 class="font-display text-xl tracking-tight text-glow mt-2">
        You don't organize any groups yet.
      </h2>
      <p class="mt-2 text-sm text-base-content/60 max-w-xl">
        Create a group to start hosting huddlz. Once you have a group, this overview will fill in with upcoming huddlz, RSVP totals, and quick actions.
      </p>
      <.link
        navigate={~p"/groups/new"}
        class="mt-4 inline-flex items-center min-h-10 px-5 text-sm font-bold bg-primary text-primary-content border border-primary btn-neon"
      >
        Create your first group
      </.link>
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
      <h1 class="font-display text-3xl tracking-tight text-glow mt-2">{@title}.</h1>
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
        class="mt-4 inline-flex text-xs text-primary hover:underline font-medium tracking-wide uppercase"
      >
        {@cta_label} →
      </.link>
      <p :if={!@cta_path} class="mt-4 text-xs text-base-content/40 tracking-wide uppercase">
        No replacement surface available yet.
      </p>
    </div>
    """
  end

  defp create_huddl_path([]), do: ~p"/groups"
  defp create_huddl_path([group | _]), do: ~p"/groups/#{group.slug}/huddlz/new"

  defp rsvp_label(0), do: "0 RSVPs"
  defp rsvp_label(1), do: "1 RSVP"
  defp rsvp_label(n), do: "#{n} RSVPs"

  defp format_starts_at(%DateTime{} = dt) do
    Calendar.strftime(dt, "%b %d, %Y · %I:%M %p")
  end

  defp format_starts_at(_), do: ""
end
