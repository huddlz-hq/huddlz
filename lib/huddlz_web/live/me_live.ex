defmodule HuddlzWeb.MeLive do
  @moduledoc """
  Member dashboard. Tabs (My Huddlz / My Groups / Invites / Updates) sit
  under `/me?tab=...`; My Huddlz is the default and shows the signed-in
  user's upcoming RSVPs, waitlisted spots, and past attendance.

  Hosting moves to the organizer workspace (Phase 3); this surface is
  participant-centered.
  """
  use HuddlzWeb, :live_view

  require Ash.Query

  alias Huddlz.Communities
  alias Huddlz.Communities.Group
  alias Huddlz.Notifications
  alias HuddlzWeb.Layouts

  @section_limit 6
  @updates_limit 20
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
     |> assign(:past, empty_section())
     |> assign(:hosting_groups, empty_section())
     |> assign(:joined_groups, empty_section())
     |> assign(:updates, [])
     |> assign(:unread_updates, 0)
     |> assign(:invites, [])}
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

  defp load_tab(socket, :groups, user) do
    socket
    |> assign(:hosting_groups, load_groups_section(user, :get_by_owner))
    |> assign(:joined_groups, load_groups_section(user, :get_joined))
  end

  defp load_tab(socket, :updates, user) do
    {updates, unread} = load_updates(user)

    socket
    |> assign(:updates, updates)
    |> assign(:unread_updates, unread)
  end

  defp load_tab(socket, :invites, user) do
    assign(socket, :invites, load_invites(user))
  end

  defp load_tab(socket, _tab, _user), do: socket

  defp load_updates(user) do
    case Notifications.list_for_user(actor: user, page: [limit: @updates_limit, count: true]) do
      {:ok, %{results: results}} ->
        unread = Enum.count(results, &is_nil(&1.read_at))
        {results, unread}

      _ ->
        {[], 0}
    end
  end

  defp load_invites(user) do
    case Notifications.list_invites_for_user(actor: user, page: [limit: @updates_limit]) do
      {:ok, %{results: results}} -> results
      _ -> []
    end
  end

  @impl true
  def handle_event("mark_read", %{"id" => id}, socket) do
    user = socket.assigns.current_user

    with {:ok, notification} <- Ash.get(Notifications.Notification, id, actor: user),
         {:ok, _updated} <- Notifications.mark_read(notification, actor: user) do
      {:noreply, load_tab(socket, socket.assigns.tab, user)}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("mark_all_read", _params, socket) do
    user = socket.assigns.current_user

    socket.assigns.updates
    |> Enum.filter(&is_nil(&1.read_at))
    |> Enum.each(fn notification ->
      Notifications.mark_read(notification, actor: user)
    end)

    {:noreply, load_tab(socket, socket.assigns.tab, user)}
  end

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

  defp load_groups_section(user, action) do
    case Group
         |> Ash.Query.for_read(action, %{}, actor: user)
         |> Ash.Query.load(:current_image_url)
         |> Ash.Query.sort(name: :asc)
         |> Ash.read(actor: user) do
      {:ok, groups} -> {groups, length(groups)}
      _ -> empty_section()
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
            <h1 class="text-3xl font-extrabold tracking-tight text-base-content mt-2">
              My huddlz.
            </h1>
            <p :if={tab_intro(@tab)} class="mt-2 text-base-content/60 max-w-2xl">
              {tab_intro(@tab)}
            </p>
          </div>
          <.button variant="primary" navigate={~p"/discover"} class="self-start lg:self-end">
            Find another huddl
          </.button>
        </header>

        <nav class="flex flex-wrap items-center gap-2" aria-label="Member dashboard tabs">
          <.page_tab patch={tab_path(:huddlz)} active={@tab == :huddlz}>My Huddlz</.page_tab>
          <.page_tab patch={tab_path(:groups)} active={@tab == :groups}>My Groups</.page_tab>
          <.page_tab patch={tab_path(:invites)} active={@tab == :invites}>Invites</.page_tab>
          <.page_tab patch={tab_path(:updates)} active={@tab == :updates}>Updates</.page_tab>
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
            <.groups_tab
              hosting={@hosting_groups}
              joined={@joined_groups}
              limit={@section_limit}
            />
          <% :invites -> %>
            <.invites_tab invites={@invites} />
          <% :updates -> %>
            <.updates_tab updates={@updates} unread={@unread_updates} />
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

  attr :hosting, :any, required: true
  attr :joined, :any, required: true
  attr :limit, :integer, required: true

  defp groups_tab(assigns) do
    ~H"""
    <div class="grid grid-cols-1 gap-8 lg:grid-cols-3 lg:gap-10">
      <div class="space-y-12 lg:col-span-2">
        <.groups_section
          title="Hosting"
          section={@hosting}
          limit={@limit}
          view_all_path={~p"/groups?yours=hosting"}
          empty_message="You haven't created a group yet."
        />

        <.groups_section
          title="Joined"
          section={@joined}
          limit={@limit}
          view_all_path={~p"/groups?yours=joined"}
          empty_message="You haven't joined any groups yet."
        />
      </div>

      <aside class="space-y-6">
        <.find_more_groups_panel />
        <.groups_next_actions_panel />
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
        <h2 class="text-lg font-extrabold tracking-tight text-base-content flex items-baseline gap-3">
          <span class="mono-label text-primary/70">// {@title}</span>
          <span class="text-sm font-body font-normal text-base-content/40">
            ({@count})
          </span>
        </h2>
        <.link
          :if={@view_all_path && @count > @limit}
          navigate={@view_all_path}
          class="text-xs font-bold text-primary hover:underline"
        >
          View all →
        </.link>
      </div>

      <%= if @count == 0 do %>
        <.surface_panel variant="dashed" class="p-8 mt-4 text-center text-base-content/50">
          {@empty_message}
        </.surface_panel>
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
    <.surface_panel class="p-6">
      <span class="mono-label text-primary/70">// Coming up</span>
      <%= if @next do %>
        <h3 class="text-lg font-extrabold tracking-tight text-base-content mt-3">
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
          class="mt-4 inline-flex text-xs font-bold text-primary hover:underline"
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
    </.surface_panel>
    """
  end

  defp next_actions_panel(assigns) do
    ~H"""
    <.surface_panel class="p-6">
      <span class="mono-label text-primary/70">// Useful next actions</span>
      <ul class="mt-3 space-y-2 text-sm text-base-content/70">
        <li>View event details and location.</li>
        <li>Change RSVP or add a guest.</li>
        <li>Message the organizer if something changes.</li>
      </ul>
    </.surface_panel>
    """
  end

  attr :title, :string, required: true
  attr :section, :any, required: true
  attr :limit, :integer, required: true
  attr :view_all_path, :any, default: nil
  attr :empty_message, :string, required: true

  defp groups_section(assigns) do
    {groups, count} = assigns.section
    assigns = assign(assigns, groups: groups, count: count)

    ~H"""
    <section>
      <div class="flex items-baseline justify-between gap-2">
        <h2 class="text-lg font-extrabold tracking-tight text-base-content flex items-baseline gap-3">
          <span class="mono-label text-primary/70">// {@title}</span>
          <span class="text-sm font-body font-normal text-base-content/40">
            ({@count})
          </span>
        </h2>
        <.link
          :if={@view_all_path && @count > @limit}
          navigate={@view_all_path}
          class="text-xs font-bold text-primary hover:underline"
        >
          View all →
        </.link>
      </div>

      <%= if @count == 0 do %>
        <.surface_panel variant="dashed" class="p-8 mt-4 text-center text-base-content/50">
          {@empty_message}
        </.surface_panel>
      <% else %>
        <div class="grid gap-6 sm:grid-cols-2 mt-4">
          <%= for group <- Enum.take(@groups, @limit) do %>
            <.group_card group={group} />
          <% end %>
        </div>
      <% end %>
    </section>
    """
  end

  defp find_more_groups_panel(assigns) do
    ~H"""
    <.surface_panel class="p-6">
      <span class="mono-label text-primary/70">// Find more groups</span>
      <p class="text-sm text-base-content/60 mt-3">
        Browse groups near you, by topic, or by name.
      </p>
      <.link
        navigate={~p"/discover?scope=groups"}
        class="mt-4 inline-flex text-xs font-bold text-primary hover:underline"
      >
        Discover groups →
      </.link>
    </.surface_panel>
    """
  end

  defp groups_next_actions_panel(assigns) do
    ~H"""
    <.surface_panel class="p-6">
      <span class="mono-label text-primary/70">// Useful next actions</span>
      <ul class="mt-3 space-y-2 text-sm text-base-content/70">
        <li>Open a group's home page to see its upcoming huddlz.</li>
        <li>
          <.link navigate={~p"/profile/notifications"} class="text-primary hover:underline">
            Manage notifications
          </.link>
          per group from your profile.
        </li>
        <li>Browse more groups on Discover.</li>
      </ul>
    </.surface_panel>
    """
  end

  attr :updates, :list, required: true
  attr :unread, :integer, required: true

  defp updates_tab(assigns) do
    ~H"""
    <div class="grid grid-cols-1 gap-8 lg:grid-cols-3 lg:gap-10">
      <div class="lg:col-span-2 space-y-6">
        <div class="flex items-baseline justify-between gap-2">
          <h2 class="text-lg font-extrabold tracking-tight text-base-content flex items-baseline gap-3">
            <span class="mono-label text-primary/70">// Updates</span>
            <span :if={@unread > 0} class="text-sm font-body font-normal text-primary">
              ({@unread} unread)
            </span>
          </h2>
          <button
            :if={@unread > 0}
            type="button"
            phx-click="mark_all_read"
            class="text-xs font-bold text-primary hover:underline"
          >
            Mark all as read
          </button>
        </div>

        <%= if @updates == [] do %>
          <.surface_panel variant="dashed" class="p-8 text-center text-base-content/50">
            No updates yet. Reminders and group activity will appear here as they happen.
          </.surface_panel>
        <% else %>
          <ul class="space-y-3" id="updates-list">
            <%= for notification <- @updates do %>
              <.notification_card notification={notification} />
            <% end %>
          </ul>
        <% end %>
      </div>

      <aside class="space-y-6">
        <.notification_controls_panel />
        <.updates_next_actions_panel />
      </aside>
    </div>
    """
  end

  attr :notification, :map, required: true

  defp notification_card(assigns) do
    read? = !is_nil(assigns.notification.read_at)
    assigns = assign(assigns, :read?, read?)

    ~H"""
    <.surface_panel
      tag="li"
      id={"notification-#{@notification.id}"}
      class={[
        "p-5",
        @read? && "opacity-60"
      ]}
    >
      <div class="flex items-start justify-between gap-4">
        <div class="flex-1 min-w-0">
          <div class="flex items-baseline gap-2 flex-wrap">
            <.huddl_badge variant="cyan">{category_label(@notification.trigger)}</.huddl_badge>
            <span class="text-xs text-base-content/50">
              {format_time_ago(@notification.inserted_at)}
            </span>
          </div>
          <h3 class="text-base font-extrabold tracking-tight text-base-content mt-2">
            {@notification.title}
          </h3>
          <p :if={@notification.description} class="text-sm text-base-content/60 mt-1">
            {@notification.description}
          </p>
        </div>

        <div class="flex items-center gap-3 flex-shrink-0">
          <.link
            :if={@notification.source_url}
            navigate={@notification.source_url}
            class="text-xs font-bold text-primary hover:underline"
          >
            View →
          </.link>
          <button
            :if={!@read?}
            type="button"
            phx-click="mark_read"
            phx-value-id={@notification.id}
            class="text-xs font-bold text-base-content/50 hover:text-primary"
          >
            Mark read
          </button>
        </div>
      </div>
    </.surface_panel>
    """
  end

  defp notification_controls_panel(assigns) do
    ~H"""
    <.surface_panel class="p-6">
      <span class="mono-label text-primary/70">// Notification controls</span>
      <p class="text-sm text-base-content/60 mt-3">
        Tune which events email you and which stay in-app only.
      </p>
      <.link
        navigate={~p"/profile/notifications"}
        class="mt-4 inline-flex text-xs font-bold text-primary hover:underline"
      >
        Open preferences →
      </.link>
    </.surface_panel>
    """
  end

  defp updates_next_actions_panel(assigns) do
    ~H"""
    <.surface_panel class="p-6">
      <span class="mono-label text-primary/70">// Useful next actions</span>
      <ul class="mt-3 space-y-2 text-sm text-base-content/70">
        <li>Jump to the related huddl or group with View.</li>
        <li>Mark items as read once you've handled them.</li>
        <li>Tune notification preferences in your profile.</li>
      </ul>
    </.surface_panel>
    """
  end

  attr :invites, :list, required: true

  defp invites_tab(assigns) do
    ~H"""
    <div class="grid grid-cols-1 gap-8 lg:grid-cols-3 lg:gap-10">
      <div class="lg:col-span-2 space-y-6">
        <div class="flex items-baseline justify-between gap-2">
          <h2 class="text-lg font-extrabold tracking-tight text-base-content flex items-baseline gap-3">
            <span class="mono-label text-primary/70">// Invites</span>
            <span :if={@invites != []} class="text-sm font-body font-normal text-base-content/40">
              ({length(@invites)})
            </span>
          </h2>
        </div>

        <%= if @invites == [] do %>
          <.surface_panel variant="dashed" class="p-8 text-center text-base-content/50">
            No invites right now. When organizers invite you to a huddl or group, they'll show up here.
          </.surface_panel>
        <% else %>
          <ul class="space-y-3" id="invites-list">
            <%= for notification <- @invites do %>
              <.notification_card notification={notification} />
            <% end %>
          </ul>
        <% end %>
      </div>

      <aside class="space-y-6">
        <.needs_response_panel />
        <.invites_next_actions_panel />
      </aside>
    </div>
    """
  end

  defp needs_response_panel(assigns) do
    ~H"""
    <.surface_panel class="p-6">
      <span class="mono-label text-primary/70">// Needs response</span>
      <p class="text-sm text-base-content/60 mt-3">
        Invites are lightweight. Open the related huddl or group to take action, then mark the invite read.
      </p>
    </.surface_panel>
    """
  end

  defp invites_next_actions_panel(assigns) do
    ~H"""
    <.surface_panel class="p-6">
      <span class="mono-label text-primary/70">// Useful next actions</span>
      <ul class="mt-3 space-y-2 text-sm text-base-content/70">
        <li>Open a waitlist promotion to confirm or cancel.</li>
        <li>Visit a group you've been added to.</li>
        <li>Mark each invite read once you've handled it.</li>
      </ul>
    </.surface_panel>
    """
  end

  defp category_label(trigger) when is_binary(trigger) do
    case Notifications.Triggers.fetch(String.to_existing_atom(trigger)) do
      {:ok, %{category: :transactional}} -> "Transactional"
      {:ok, %{category: :activity}} -> "Activity"
      {:ok, %{category: :digest}} -> "Digest"
      _ -> "Update"
    end
  rescue
    ArgumentError -> "Update"
  end

  defp format_time_ago(%DateTime{} = dt) do
    diff_seconds = DateTime.diff(DateTime.utc_now(), dt, :second)

    cond do
      diff_seconds < 60 -> "just now"
      diff_seconds < 3600 -> "#{div(diff_seconds, 60)}m ago"
      diff_seconds < 86_400 -> "#{div(diff_seconds, 3600)}h ago"
      diff_seconds < 7 * 86_400 -> "#{div(diff_seconds, 86_400)}d ago"
      true -> Calendar.strftime(dt, "%b %d, %Y")
    end
  end

  defp tab_path(tab), do: ~p"/me?#{[tab: tab]}"

  defp tab_intro(:huddlz),
    do: "Your upcoming RSVPs, waitlisted spots, and past gatherings — all in one place."

  defp tab_intro(:groups), do: "Groups you organize and groups you've joined."

  defp tab_intro(:invites),
    do: "Things that need a response from you."

  defp tab_intro(:updates),
    do: "Reminders, RSVPs, and group activity from across huddlz."

  defp tab_intro(_), do: nil

  defp format_starts_at(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y · %I:%M %p")
  end
end
