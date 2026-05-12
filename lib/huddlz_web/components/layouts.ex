defmodule HuddlzWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.
  """
  use HuddlzWeb, :html

  alias Huddlz.Accounts.User
  alias HuddlzWeb.Avatar

  embed_templates "layouts/*"

  @doc """
  V3 app layout — sidebar + topbar shell wrapping the inner content.

  Mirrors the clickthrough mockup at `/dev/design/clickthrough/explore` (and
  the `clickthrough_shell` function component in `HuddlzWeb.DevDesignHTML`),
  but reads the real `current_user` and renders an admin link when the user
  is an admin.

  Pair with `on_mount {HuddlzWeb.LiveUserAuth, :v3_app}` to flip the body
  class to `"v3"` so the v3 styles in `app.css` take effect.
  """
  attr :flash, :map, required: true
  attr :current_user, :map, default: nil

  attr :active, :string,
    default: nil,
    doc: "active surface key for nav highlighting (e.g. \"discover\", \"my-huddlz\")"

  attr :active_group_slug, :string,
    default: nil,
    doc: "slug of the group currently being organized (expands its sb-org-row sub-tabs)"

  attr :active_organize_section, :atom,
    default: nil,
    values: [nil, :overview, :huddlz, :members],
    doc: "active sub-tab inside an organize-group section"

  attr :sidebar_owned_groups, :list,
    default: [],
    doc: "groups the current_user organizes — rendered as sb-org-row entries"

  attr :query, :string, default: "", doc: "current search query — prefilled in topbar input"
  slot :inner_block, required: true

  def v3_app(assigns) do
    assigns = assign_new(assigns, :signed_in, fn -> assigns.current_user != nil end)

    ~H"""
    <%= if @signed_in do %>
      <input type="checkbox" id="nav-toggle" class="nav-toggle" />
      <label for="nav-toggle" class="nav-scrim" aria-hidden="true"></label>
      <aside class="sidebar">
        <a class="sidebar-brand" href="/">
          <div class="brand-glyph">h</div>
          <div class="brand-text">huddlz</div>
        </a>

        <nav class="sb-nav">
          <a class={["sb-item", @active == "discover" && "active"]} href="/discover">
            <.v3_nav_icon name="search" />
            <span class="label">Discover</span>
          </a>
          <a class={["sb-item", @active == "my-huddlz" && "active"]} href="/my-huddlz">
            <.v3_nav_icon name="ticket" />
            <span class="label">My huddlz</span>
          </a>
          <a class={["sb-item", @active == "my-groups" && "active"]} href="/my-groups">
            <.v3_nav_icon name="users" />
            <span class="label">My groups</span>
          </a>
          <a class={["sb-item", @active == "calendar" && "active"]} href="/calendar">
            <.v3_nav_icon name="calendar" />
            <span class="label">My calendar</span>
          </a>

          <div class="sb-orgs">
            <%= for {group, idx} <- Enum.with_index(@sidebar_owned_groups) do %>
              <a
                class={[
                  "sb-org-row",
                  @active_group_slug == group.slug && "active"
                ]}
                href={"/organize/#{group.slug}"}
              >
                <div class={["group-mark", group_mark_variant(idx)]}>
                  {group_initials(group.name)}
                </div>
                <span class="name">{group.name}</span>
              </a>
              <div :if={@active_group_slug == group.slug} class="sb-sub">
                <a
                  class={["sb-sub-item", @active_organize_section == :overview && "active"]}
                  href={"/organize/#{group.slug}"}
                >
                  Overview
                </a>
                <a
                  class={["sb-sub-item", @active_organize_section == :huddlz && "active"]}
                  href={"/organize/#{group.slug}/huddlz"}
                >
                  Huddlz
                </a>
                <a
                  class={["sb-sub-item", @active_organize_section == :members && "active"]}
                  href={"/organize/#{group.slug}/members"}
                >
                  Members
                </a>
              </div>
            <% end %>
            <a class="sb-org-row create" href="/groups/new">
              <div class="plus-mark">+</div>
              <span class="name">New group</span>
            </a>
          </div>
        </nav>

        <div class="sb-account">
          <a class={["sb-item", @active == "profile" && "active"]} href="/profile">
            <.v3_nav_icon name="user" />
            <span class="label">Profile</span>
          </a>
          <a
            class={["sb-item", @active == "settings" && "active"]}
            href="/profile/notifications"
          >
            <.v3_nav_icon name="cog" />
            <span class="label">Settings</span>
          </a>
          <a class={["sb-item", @active == "help" && "active"]} href="/help">
            <.v3_nav_icon name="help" />
            <span class="label">Help</span>
          </a>
          <%= if User.admin?(@current_user) do %>
            <a class={["sb-item", @active == "admin" && "active"]} href="/admin">
              <.v3_nav_icon name="shield" />
              <span class="label">Admin</span>
            </a>
          <% end %>
        </div>

        <a class="sb-user" href="/profile" aria-label="View profile">
          <.sb_user_avatar user={@current_user} />
          <div class="who">
            <div class="name">{display_name(@current_user)}</div>
            <div class="role">{@current_user.email}</div>
          </div>
        </a>
      </aside>
    <% end %>

    <main class="main">
      <header class="content-topbar">
        <%= if @signed_in do %>
          <label for="nav-toggle" class="nav-trigger" aria-label="Open navigation">
            <.v3_nav_icon name="bars" />
          </label>
        <% else %>
          <a class="topbar-brand" href="/" aria-label="huddlz home">
            <div class="brand-glyph">h</div>
            <div class="brand-text">huddlz</div>
          </a>
        <% end %>
        <form class="topbar-search" action="/discover" method="get" role="search">
          <span class="lead-key" aria-hidden="true">/</span>
          <input type="search" name="q" placeholder="Search huddlz" value={@query} />
        </form>
        <div class="content-actions">
          <%= if @signed_in do %>
            <a
              class={["icon-pill", @active == "notifications" && "active"]}
              href="/notifications"
              aria-label="Notifications"
            >
              <.v3_nav_icon name="bell" />
            </a>
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

  @doc """
  V3 auth shell — chromeless wrapper used by `/sign-in`, `/register`, `/reset`,
  and `/reset/:token`. Renders the brand topbar, the flash group, and an
  `auth-frame` container around the inner content.

  Pair with `assign(socket, :body_class, "v3 is-auth")` in the LiveView's
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

  defp v3_nav_icon(%{name: "search"} = assigns) do
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

  defp v3_nav_icon(%{name: "ticket"} = assigns) do
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

  defp v3_nav_icon(%{name: "users"} = assigns) do
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

  defp v3_nav_icon(%{name: "calendar"} = assigns) do
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

  defp v3_nav_icon(%{name: "user"} = assigns) do
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

  defp v3_nav_icon(%{name: "cog"} = assigns) do
    ~H"""
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.8"
      stroke-linecap="round"
      stroke-linejoin="round"
    >
      <circle cx="12" cy="12" r="3" /><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1Z" />
    </svg>
    """
  end

  defp v3_nav_icon(%{name: "help"} = assigns) do
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

  defp v3_nav_icon(%{name: "shield"} = assigns) do
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

  defp v3_nav_icon(%{name: "bars"} = assigns) do
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

  defp v3_nav_icon(%{name: "bell"} = assigns) do
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
    <div id={@id} aria-live="polite">
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

  defp group_initials(nil), do: "??"

  defp group_initials(name) do
    name
    |> to_string()
    |> String.trim()
    |> String.split(~r/[\s\-_]+/, trim: true)
    |> case do
      [] -> "??"
      [single] -> single |> String.slice(0, 2) |> String.upcase()
      [first, second | _] -> String.upcase(String.first(first) <> String.first(second))
    end
  end

  defp group_mark_variant(idx) do
    case rem(idx, 3) do
      0 -> ""
      1 -> "mark-magenta"
      2 -> "mark-warm"
    end
  end
end
