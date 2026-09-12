defmodule HuddlzWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.
  """
  use HuddlzWeb, :html

  alias Huddlz.Accounts.User
  alias HuddlzWeb.Avatar

  embed_templates "layouts/*"

  @doc """
  Main app layout — sidebar + topbar shell wrapping the inner content.

  Reads the real `current_user` and renders an admin link when the user is
  an admin.

  Pair with `on_mount {HuddlzWeb.LiveUserAuth, :app}`, which loads the
  sidebar's `sb-org-row` groups and sets the chromeless-mode body class
  when there's no actor.
  """
  attr :flash, :map, required: true
  attr :current_user, :map, default: nil
  attr :unread_notification_count, :integer, default: 0

  attr :active, :string,
    default: nil,
    doc: "active surface key for nav highlighting (e.g. \"discover\", \"agenda\")"

  attr :active_group_slug, :string,
    default: nil,
    doc: "slug of the group currently being organized (expands its sb-org-row sub-tabs)"

  attr :active_organize_section, :atom,
    default: nil,
    values: [nil, :overview, :huddlz, :members, :settings],
    doc: "active sub-tab inside an organize-group section"

  attr :active_admin_section, :atom,
    default: nil,
    values: [nil, :overview, :users],
    doc: "active sub-item under the Admin sidebar item"

  attr :sidebar_owned_groups, :list,
    default: [],
    doc: "groups the current_user organizes — rendered as sb-org-row entries"

  attr :query, :string, default: "", doc: "current search query — prefilled in topbar input"
  slot :inner_block, required: true

  def app(assigns) do
    assigns = assign_new(assigns, :signed_in, fn -> assigns.current_user != nil end)

    ~H"""
    <%= if @signed_in do %>
      <button
        type="button"
        class="nav-scrim"
        data-mobile-nav-scrim
        aria-hidden="true"
        tabindex="-1"
      ></button>
      <aside
        id="mobile-navigation-drawer"
        class="sidebar"
        data-mobile-nav-state="closed"
        aria-label="Primary navigation"
      >
        <div class="sidebar-brand">
          <.link navigate={~p"/"} aria-label="huddlz home">
            <div class="brand-glyph">h</div>
            <div class="brand-text">huddlz</div>
          </.link>
          <button
            type="button"
            id="mobile-nav-close"
            class="nav-close"
            data-mobile-nav-close
            aria-label="Close navigation"
          >
            <.icon name="hero-x-mark" class="size-5" />
          </button>
        </div>

        <nav class="sb-nav">
          <.link
            class={["sb-item", @active == "discover" && "active"]}
            navigate={~p"/discover"}
            aria-current={@active == "discover" && "page"}
          >
            <.nav_icon name="search" />
            <span class="label">Discover</span>
          </.link>
          <.link
            class={["sb-item", @active == "agenda" && "active"]}
            navigate={~p"/agenda"}
            aria-current={@active == "agenda" && "page"}
          >
            <.icon name="hero-list-bullet" class="sb-icon" />
            <span class="label">Agenda</span>
          </.link>
          <.link
            class={["sb-item", @active == "groups" && "active"]}
            navigate={~p"/groups"}
            aria-current={@active == "groups" && "page"}
          >
            <.nav_icon name="users" />
            <span class="label">Groups</span>
          </.link>
          <.link
            class={["sb-item", @active == "calendar" && "active"]}
            navigate={~p"/calendar/week"}
            aria-current={@active == "calendar" && "page"}
          >
            <.nav_icon name="calendar" />
            <span class="label">Calendar</span>
          </.link>

          <div class="sb-orgs">
            <%= for {group, idx} <- Enum.with_index(@sidebar_owned_groups) do %>
              <.link
                class={[
                  "sb-org-row",
                  @active_group_slug == group.slug && "active"
                ]}
                navigate={~p"/organize/#{group.slug}"}
                aria-current={
                  @active_group_slug == group.slug && is_nil(@active_organize_section) && "page"
                }
              >
                <div class={["group-mark", group_mark_variant(idx)]}>
                  {group_initials(group.name)}
                </div>
                <span class="name">
                  <span class="block truncate">{group.name}</span>
                  <span
                    :if={role = HuddlzWeb.GroupRole.label(group.viewer_role)}
                    class="block text-xs font-normal text-base-content/70"
                  >
                    {role}
                  </span>
                </span>
              </.link>
              <div :if={@active_group_slug == group.slug} class="sb-sub">
                <.link
                  class={["sb-sub-item", @active_organize_section == :overview && "active"]}
                  navigate={~p"/organize/#{group.slug}"}
                  aria-current={@active_organize_section == :overview && "page"}
                >
                  Overview
                </.link>
                <.link
                  class={["sb-sub-item", @active_organize_section == :huddlz && "active"]}
                  navigate={~p"/organize/#{group.slug}/huddlz"}
                  aria-current={@active_organize_section == :huddlz && "page"}
                >
                  Huddlz
                </.link>
                <.link
                  class={["sb-sub-item", @active_organize_section == :members && "active"]}
                  navigate={~p"/organize/#{group.slug}/members"}
                  aria-current={@active_organize_section == :members && "page"}
                >
                  Members
                </.link>
                <.link
                  :if={group.owner_id == @current_user.id}
                  class={["sb-sub-item", @active_organize_section == :settings && "active"]}
                  navigate={~p"/organize/#{group.slug}/settings"}
                  aria-current={@active_organize_section == :settings && "page"}
                >
                  Group settings
                </.link>
              </div>
            <% end %>
            <.link class="sb-org-row create" navigate={~p"/groups/new"}>
              <div class="plus-mark">+</div>
              <span class="name">New group</span>
            </.link>
          </div>
        </nav>

        <div class="sb-account">
          <.link
            class={["sb-item", @active == "profile" && "active"]}
            navigate={~p"/profile"}
            aria-current={@active == "profile" && "page"}
          >
            <.nav_icon name="user" />
            <span class="label">Profile</span>
          </.link>
          <.link
            class={["sb-item", @active == "preferences" && "active"]}
            navigate={~p"/profile/notifications"}
            aria-current={@active == "preferences" && "page"}
          >
            <.nav_icon name="bell" />
            <span class="label">Notifications</span>
          </.link>
          <.link
            class={["sb-item", @active == "help" && "active"]}
            navigate={~p"/help"}
            aria-current={@active == "help" && "page"}
          >
            <.nav_icon name="help" />
            <span class="label">Help</span>
          </.link>
          <.link
            id="sign-out-link"
            class="sb-item"
            href={~p"/sign-out"}
            method="delete"
            aria-label="Sign out"
          >
            <.icon name="hero-arrow-right-start-on-rectangle" class="size-[18px]" />
            <span class="label">Sign out</span>
          </.link>
          <%= if User.admin?(@current_user) do %>
            <.link
              class={["sb-item", @active == "admin" && "active"]}
              navigate={~p"/admin"}
              aria-current={@active == "admin" && is_nil(@active_admin_section) && "page"}
            >
              <.nav_icon name="shield" />
              <span class="label">Admin</span>
            </.link>
            <div :if={@active == "admin"} class="sb-sub">
              <.link
                class={["sb-sub-item", @active_admin_section == :overview && "active"]}
                navigate={~p"/admin"}
                aria-current={@active_admin_section == :overview && "page"}
              >
                Overview
              </.link>
              <.link
                class={["sb-sub-item", @active_admin_section == :users && "active"]}
                navigate={~p"/admin/users"}
                aria-current={@active_admin_section == :users && "page"}
              >
                Users
              </.link>
            </div>
          <% end %>
        </div>

        <.link id="sidebar-user" class="sb-user" navigate={~p"/profile"} aria-label="View profile">
          <.sb_user_avatar user={@current_user} />
          <div class="who">
            <div class="name">{display_name(@current_user)}</div>
            <div class="role">{@current_user.email}</div>
          </div>
        </.link>
      </aside>
    <% end %>

    <main class="main" data-mobile-nav-background>
      <header class="content-topbar">
        <%= if @signed_in do %>
          <button
            type="button"
            id="mobile-nav-trigger"
            class="nav-trigger"
            data-mobile-nav-trigger
            aria-label="Open navigation"
            aria-controls="mobile-navigation-drawer"
            aria-expanded="false"
          >
            <.nav_icon name="bars" />
          </button>
        <% else %>
          <.link class="topbar-brand" navigate={~p"/"} aria-label="huddlz home">
            <div class="brand-glyph">h</div>
            <div class="brand-text">huddlz</div>
          </.link>
        <% end %>
        <form class="topbar-search" action="/discover" method="get" role="search">
          <span class="lead-key" aria-hidden="true">/</span>
          <input
            type="search"
            name="q"
            aria-label="Search huddlz"
            placeholder="Search huddlz"
            value={@query}
          />
        </form>
        <div class="content-actions">
          <%= if @signed_in do %>
            <.theme_menu current={theme_current(@current_user)} />
            <.link
              id="notification-nav-link"
              class={["icon-pill", @active == "notifications" && "active"]}
              navigate={~p"/notifications"}
              aria-label={notification_label(@unread_notification_count)}
              aria-current={@active == "notifications" && "page"}
            >
              <.nav_icon name="bell" />
              <span
                :if={@unread_notification_count > 0}
                id="notification-nav-badge"
                class="notification-badge"
                aria-hidden="true"
              >
                {compact_notification_count(@unread_notification_count)}
              </span>
            </.link>
          <% else %>
            <a class="btn-secondary" href="/sign-in">Sign in</a>
            <a class="btn-primary" href="/register">Sign up</a>
          <% end %>
        </div>
      </header>

      <div class="content-body">
        <.flash_group flash={@flash} />
        {render_slot(@inner_block)}
      </div>
    </main>
    """
  end

  attr :current, :atom, required: true, values: [:system, :light, :dark]

  # A native popover: the trigger's `popovertarget` opens it, each option's
  # `popovertargetaction="hide"` closes it on pick, and the browser handles
  # Escape, click-away and returning focus to the trigger.
  defp theme_menu(assigns) do
    ~H"""
    <button
      type="button"
      id="theme-menu-trigger"
      class="icon-pill"
      popovertarget="theme-menu"
      aria-label={"Appearance: #{theme_label(@current)}"}
      title="Appearance"
    >
      <.icon name={theme_icon(@current)} class="size-4" />
    </button>
    <div id="theme-menu" class="theme-menu" popover="auto" role="menu" aria-label="Appearance">
      <div class="theme-menu-title" aria-hidden="true">Appearance</div>
      <button
        :for={{value, label, icon, hint} <- theme_options()}
        type="button"
        class="theme-option"
        role="menuitemradio"
        aria-checked={to_string(@current == value)}
        phx-click="set_theme"
        phx-value-theme={value}
        popovertarget="theme-menu"
        popovertargetaction="hide"
      >
        <.icon name={icon} class="size-4 theme-option-icon" />
        <span class="theme-option-text">
          <span class="theme-option-label">{label}</span>
          <span class="theme-option-hint">{hint}</span>
        </span>
        <.icon :if={@current == value} name="hero-check" class="size-4 theme-option-check" />
      </button>
    </div>
    """
  end

  defp theme_options do
    [
      {:system, "System", "hero-computer-desktop", "Follows your device"},
      {:light, "Light", "hero-sun", "Always light"},
      {:dark, "Dark", "hero-moon", "Always dark"}
    ]
  end

  defp theme_current(%{theme_preference: theme}) when theme in [:light, :dark], do: theme
  defp theme_current(_user), do: :system

  defp theme_label(current) do
    {_value, label, _icon, _hint} = List.keyfind!(theme_options(), current, 0)
    label
  end

  defp theme_icon(current) do
    {_value, _label, icon, _hint} = List.keyfind!(theme_options(), current, 0)
    icon
  end

  defp notification_label(0), do: "Notifications"

  defp notification_label(count),
    do: "Notifications, #{count} unread"

  defp compact_notification_count(count) when count > 99, do: "99+"
  defp compact_notification_count(count), do: count

  @doc """
  V3 auth shell — chromeless wrapper used by `/sign-in`, `/register`, `/reset`,
  and `/reset/:token`. Renders the brand topbar, the flash group, and an
  `auth-frame` container around the inner content.

  Pair with `assign(socket, :body_class, "is-auth")` in the LiveView's
  `mount/3` so the v3 auth styles in `app.css` take effect.
  """
  attr :flash, :map, required: true
  slot :inner_block, required: true

  def auth_shell(assigns) do
    ~H"""
    <Layouts.flash_group flash={@flash} />

    <div class="auth-shell">
      <header class="auth-topbar">
        <a href={~p"/"}>
          <div class="brand-glyph">h</div>
          <div class="brand-text">huddlz</div>
        </a>
      </header>

      <div class="auth-frame">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  @doc """
  Cyan check or warn circle inside `.icon-mark` — used by auth-state success
  and expired/invalid blocks.
  """
  attr :name, :string, required: true, values: ~w(check warn)

  def auth_state_icon(%{name: "check"} = assigns) do
    ~H"""
    <svg
      width="22"
      height="22"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
    >
      <path d="M5 13l4 4L19 7" />
    </svg>
    """
  end

  def auth_state_icon(%{name: "warn"} = assigns) do
    ~H"""
    <svg
      width="22"
      height="22"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.8"
      stroke-linecap="round"
      stroke-linejoin="round"
    >
      <circle cx="12" cy="12" r="9" /><path d="M12 7v6" /><path d="M12 17h.01" />
    </svg>
    """
  end

  attr :name, :string, required: true

  defp nav_icon(%{name: "search"} = assigns) do
    ~H"""
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.8"
      stroke-linecap="round"
      stroke-linejoin="round"
    >
      <circle cx="11" cy="11" r="7" /><path d="m20 20-3.5-3.5" />
    </svg>
    """
  end

  defp nav_icon(%{name: "ticket"} = assigns) do
    ~H"""
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.8"
      stroke-linecap="round"
      stroke-linejoin="round"
    >
      <path d="M3 9a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2v2a2 2 0 0 0 0 4v2a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-2a2 2 0 0 0 0-4z" /><path
        d="M14 7v10"
        stroke-dasharray="2 2"
      />
    </svg>
    """
  end

  defp nav_icon(%{name: "users"} = assigns) do
    ~H"""
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.8"
      stroke-linecap="round"
      stroke-linejoin="round"
    >
      <circle cx="9" cy="9" r="3" /><circle cx="17" cy="9" r="2.5" /><path d="M3 19a6 6 0 0 1 12 0" /><path d="M14 17a5 5 0 0 1 7 2" />
    </svg>
    """
  end

  defp nav_icon(%{name: "calendar"} = assigns) do
    ~H"""
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.8"
      stroke-linecap="round"
      stroke-linejoin="round"
    >
      <rect x="3" y="5" width="18" height="16" rx="2" /><path d="M16 3v4M8 3v4M3 11h18" />
    </svg>
    """
  end

  defp nav_icon(%{name: "user"} = assigns) do
    ~H"""
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.8"
      stroke-linecap="round"
      stroke-linejoin="round"
    >
      <circle cx="12" cy="8" r="4" /><path d="M4 21a8 8 0 0 1 16 0" />
    </svg>
    """
  end

  defp nav_icon(%{name: "help"} = assigns) do
    ~H"""
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.8"
      stroke-linecap="round"
      stroke-linejoin="round"
    >
      <circle cx="12" cy="12" r="9" /><path d="M9.5 9a2.5 2.5 0 0 1 5 0c0 1.5-2.5 2-2.5 3.5" /><path d="M12 17h.01" />
    </svg>
    """
  end

  defp nav_icon(%{name: "shield"} = assigns) do
    ~H"""
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.8"
      stroke-linecap="round"
      stroke-linejoin="round"
    >
      <path d="M12 3 4 6v6c0 5 3.5 8.5 8 9 4.5-.5 8-4 8-9V6l-8-3z" />
    </svg>
    """
  end

  defp nav_icon(%{name: "bars"} = assigns) do
    ~H"""
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.8"
      stroke-linecap="round"
      stroke-linejoin="round"
    >
      <path d="M4 7h16M4 12h16M4 17h16" />
    </svg>
    """
  end

  defp nav_icon(%{name: "bell"} = assigns) do
    ~H"""
    <svg
      width="16"
      height="16"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.8"
      stroke-linecap="round"
      stroke-linejoin="round"
    >
      <path d="M18 8a6 6 0 0 0-12 0c0 7-3 9-3 9h18s-3-2-3-9" /><path d="M13.7 21a2 2 0 0 1-3.4 0" />
    </svg>
    """
  end

  defp display_name(%{display_name: name}) when is_binary(name) and name != "", do: name
  defp display_name(%{email: email}) when is_binary(email), do: email
  defp display_name(_), do: "Account"

  attr :user, :map, required: true

  defp sb_user_avatar(assigns) do
    ~H"""
    <%= cond do %>
      <% url = Avatar.picture_url(@user) -> %>
        <img class="avatar" src={url} alt="" aria-hidden="true" />
      <% initials = Avatar.initials(@user) -> %>
        <span class="avatar" aria-hidden="true">{initials}</span>
      <% true -> %>
        <span class="avatar" aria-hidden="true"></span>
    <% end %>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} class="flash-group" aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 h-3 w-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Hang in there while we get back on track")}
        <.icon name="hero-arrow-path" class="ml-1 h-3 w-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  defp group_mark_variant(idx) do
    case rem(idx, 3) do
      0 -> ""
      1 -> "mark-magenta"
      2 -> "mark-warm"
    end
  end
end
