defmodule HuddlzWeb.MeLive do
  @moduledoc """
  Member dashboard. Tabs (My Huddlz / My Groups / Invites / Updates) sit
  under `/me?tab=...`; My Huddlz is the default and shows the signed-in
  user's upcoming RSVPs, waitlisted spots, and past attendance.

  Hosting moves to the organizer workspace (Phase 3); this surface is
  participant-centered.
  """
  use HuddlzWeb, :live_view

  alias Huddlz.Communities
  alias HuddlzWeb.Layouts

  @section_limit 6
  @huddl_card_loads [:status, :rsvp_count, :visible_virtual_link, :display_image_url, :group]
  @valid_tabs ~w(huddlz groups invites updates)

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:section_limit, @section_limit)
     |> assign(:page_title, "My huddlz")
     |> assign(:upcoming, empty_section())
     |> assign(:waitlisted, empty_section())
     |> assign(:past, empty_section())}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    tab = parse_tab(params["tab"])

    {:noreply,
     socket
     |> assign(:tab, tab)
     |> load_tab(tab, socket.assigns.current_user)}
  end

  defp parse_tab(value) when value in @valid_tabs, do: String.to_existing_atom(value)
  defp parse_tab(_), do: :huddlz

  defp load_tab(socket, :huddlz, user) do
    socket
    |> assign(:upcoming, load_section(user, :attending, :upcoming, :soonest))
    |> assign(:waitlisted, load_section(user, :waitlisted, :upcoming, :soonest))
    |> assign(:past, load_section(user, :attending, :past, :newest))
  end

  defp load_tab(socket, _tab, _user), do: socket

  defp load_section(user, relationship, date_filter, sort) do
    page =
      Communities.search_huddlz(
        nil,
        date_filter,
        nil,
        nil,
        nil,
        nil,
        relationship,
        sort,
        actor: user,
        page: [limit: @section_limit, offset: 0, count: true]
      )

    case page do
      {:ok, %{results: results, count: count}} ->
        loaded = Ash.load!(results, @huddl_card_loads, actor: user)
        {loaded, count || length(loaded)}

      _ ->
        empty_section()
    end
  end

  defp empty_section, do: {[], 0}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-10">
        <header class="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
          <div>
            <span class="mono-label text-primary/70">// Signed in</span>
            <h1 class="font-display text-3xl tracking-tight text-glow mt-2">
              My huddlz.
            </h1>
            <p class="mt-2 text-base-content/60 max-w-2xl">
              Your upcoming RSVPs, waitlisted spots, and past gatherings — all in one place.
            </p>
          </div>
          <.link
            navigate={~p"/discover"}
            class="self-start lg:self-end inline-flex items-center px-5 py-2 text-sm font-medium bg-primary text-primary-content border border-primary btn-neon"
          >
            Find another huddl
          </.link>
        </header>

        <nav class="flex flex-wrap items-center gap-2" aria-label="Member dashboard tabs">
          <.link patch={tab_path(:huddlz)} class={chip_class(@tab == :huddlz)}>My Huddlz</.link>
          <.link patch={tab_path(:groups)} class={chip_class(@tab == :groups)}>My Groups</.link>
          <.link patch={tab_path(:invites)} class={chip_class(@tab == :invites)}>Invites</.link>
          <.link patch={tab_path(:updates)} class={chip_class(@tab == :updates)}>Updates</.link>
        </nav>

        <%= case @tab do %>
          <% :huddlz -> %>
            <.huddlz_tab
              upcoming={@upcoming}
              waitlisted={@waitlisted}
              past={@past}
              limit={@section_limit}
            />
          <% :groups -> %>
            <.placeholder_tab message="Coming soon — joined and organized groups will live here." />
          <% :invites -> %>
            <.placeholder_tab message="Coming soon — huddl invitations and join requests." />
          <% :updates -> %>
            <.placeholder_tab message="Coming soon — reminders and announcements." />
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  attr :upcoming, :any, required: true
  attr :waitlisted, :any, required: true
  attr :past, :any, required: true
  attr :limit, :integer, required: true

  defp huddlz_tab(assigns) do
    ~H"""
    <div class="grid grid-cols-1 gap-8 lg:grid-cols-3 lg:gap-10">
      <div class="space-y-12 lg:col-span-2">
        <.personal_section
          title="Upcoming"
          section={@upcoming}
          limit={@limit}
          view_all_path={~p"/discover?yours=attending"}
          empty_message="No upcoming RSVPs yet. Find one to attend."
        />

        <.personal_section
          title="Waitlisted"
          section={@waitlisted}
          limit={@limit}
          view_all_path={nil}
          empty_message="You're not on a waitlist right now."
        />

        <.personal_section
          title="Past"
          section={@past}
          limit={@limit}
          view_all_path={~p"/discover?yours=attending&date_filter=past"}
          empty_message="No past attendance yet."
        />
      </div>

      <aside class="space-y-6">
        <.coming_up_panel section={@upcoming} />
        <.next_actions_panel />
      </aside>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :section, :any, required: true
  attr :limit, :integer, required: true
  attr :view_all_path, :any, default: nil
  attr :empty_message, :string, required: true

  defp personal_section(assigns) do
    {huddls, count} = assigns.section
    assigns = assign(assigns, huddls: huddls, count: count)

    ~H"""
    <section>
      <div class="flex items-baseline justify-between gap-2">
        <h2 class="font-display text-lg tracking-tight text-glow flex items-baseline gap-3">
          <span class="mono-label text-primary/70">// {@title}</span>
          <span class="text-sm font-body font-normal text-base-content/40">
            ({@count})
          </span>
        </h2>
        <.link
          :if={@view_all_path && @count > @limit}
          navigate={@view_all_path}
          class="text-xs text-primary hover:underline font-medium tracking-wide uppercase"
        >
          View all →
        </.link>
      </div>

      <%= if @count == 0 do %>
        <div class="border border-dashed border-base-300 p-8 mt-4 text-center text-base-content/50">
          {@empty_message}
        </div>
      <% else %>
        <div class="grid gap-6 sm:grid-cols-2 mt-4">
          <%= for huddl <- @huddls do %>
            <.huddl_card huddl={huddl} show_group={true} />
          <% end %>
        </div>
      <% end %>
    </section>
    """
  end

  attr :section, :any, required: true

  defp coming_up_panel(assigns) do
    {huddls, _count} = assigns.section
    next = List.first(huddls)
    assigns = assign(assigns, next: next)

    ~H"""
    <div class="border border-base-300 p-6">
      <span class="mono-label text-primary/70">// Coming up</span>
      <%= if @next do %>
        <h3 class="font-display text-lg tracking-tight text-glow mt-3">
          {@next.title}
        </h3>
        <p class="text-sm text-base-content/60 mt-1">
          <span class="block">{format_starts_at(@next.starts_at)}</span>
          <span :if={@next.physical_location} class="block">{@next.physical_location}</span>
          <span :if={Map.get(@next, :group)} class="block text-base-content/40">
            {@next.group.name}
          </span>
        </p>
        <.link
          navigate={~p"/groups/#{@next.group.slug}/huddlz/#{@next.id}"}
          class="mt-4 inline-flex text-xs text-primary hover:underline font-medium tracking-wide uppercase"
        >
          View details →
        </.link>
      <% else %>
        <p class="text-sm text-base-content/60 mt-3">
          No upcoming huddlz yet.
          <.link
            navigate={~p"/discover"}
            class="text-primary hover:underline"
          >
            Find one →
          </.link>
        </p>
      <% end %>
    </div>
    """
  end

  defp next_actions_panel(assigns) do
    ~H"""
    <div class="border border-base-300 p-6">
      <span class="mono-label text-primary/70">// Useful next actions</span>
      <ul class="mt-3 space-y-2 text-sm text-base-content/70">
        <li>View event details and location.</li>
        <li>Change RSVP or add a guest.</li>
        <li>Message the organizer if something changes.</li>
      </ul>
    </div>
    """
  end

  attr :message, :string, required: true

  defp placeholder_tab(assigns) do
    ~H"""
    <div class="border border-dashed border-base-300 p-12 text-center text-base-content/50">
      {@message}
    </div>
    """
  end

  defp tab_path(tab), do: ~p"/me?#{[tab: tab]}"

  defp format_starts_at(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y · %I:%M %p")
  end

  defp chip_class(true) do
    "inline-flex items-center min-h-10 px-3.5 text-sm font-extrabold gap-2 border border-primary bg-primary text-primary-content"
  end

  defp chip_class(false) do
    "inline-flex items-center min-h-10 px-3.5 text-sm font-extrabold gap-2 border border-base-300 bg-base-100 text-base-content hover:border-primary transition-colors"
  end
end
