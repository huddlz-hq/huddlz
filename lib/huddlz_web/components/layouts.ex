defmodule HuddlzWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.
  """
  use HuddlzWeb, :html

  alias HuddlzWeb.Avatar

  embed_templates "layouts/*"

  def app(assigns) do
    ~H"""
    <header class="bg-base-100/95 backdrop-blur-sm border-b border-base-300 sticky top-0 z-50 px-6 sm:px-8 lg:px-12">
      <nav>
        <div class="flex h-20 items-center gap-5">
          <%!-- Brand --%>
          <a href="/" class="flex items-center flex-shrink-0">
            <span class="text-2xl font-extrabold tracking-tight">huddlz</span>
          </a>

          <%!-- Search (desktop) --%>
          <form
            method="get"
            action="/discover"
            role="search"
            aria-label="Search huddlz"
            class="hidden md:flex flex-1 max-w-2xl items-stretch h-12 border border-base-300 rounded-hz-control overflow-hidden bg-base-200/40 focus-within:border-primary focus-within:ring-2 focus-within:ring-primary/15 transition-colors"
          >
            <%!-- Doubles as the "/" keyboard-shortcut hint; focus handler in app.js. --%>
            <span
              class="grid place-items-center w-12 text-primary flex-shrink-0 text-lg font-bold select-none"
              aria-hidden="true"
            >
              /
            </span>
            <input
              type="search"
              name="q"
              value={assigns[:search_query] || ""}
              placeholder="Search huddlz"
              aria-label="Search huddlz"
              class="flex-1 min-w-0 border-0 bg-transparent text-base-content text-[15px] focus:outline-none focus:ring-0 placeholder:text-base-content/40"
            />
            <button
              type="submit"
              class="flex-shrink-0 px-6 bg-primary text-primary-content text-sm font-extrabold hover:brightness-110 transition-colors"
            >
              Search
            </button>
          </form>

          <%!-- Right side --%>
          <div class="ml-auto flex items-center gap-3 flex-shrink-0">
            <a
              href="/organize"
              class="hidden md:inline-flex items-center h-12 px-4 text-sm font-bold text-base-content/80 hover:text-primary transition-colors"
            >
              Organize
            </a>
            <%= if @current_user do %>
              <div class="relative">
                <button
                  type="button"
                  aria-haspopup="menu"
                  aria-controls="user-menu"
                  phx-click={JS.toggle(to: "#user-menu")}
                  class="cursor-pointer flex items-center gap-2 h-12 pl-1.5 pr-4 border border-base-300 rounded-full hover:border-primary transition-colors"
                >
                  <.avatar user={@current_user} size={:sm} class="rounded-full" />
                  <span class="hidden sm:inline font-bold text-sm text-base-content">
                    {first_name(@current_user)}
                  </span>
                </button>
                <ul
                  id="user-menu"
                  role="menu"
                  phx-click-away={JS.hide(to: "#user-menu")}
                  phx-window-keydown={JS.hide(to: "#user-menu")}
                  phx-key="escape"
                  class="hidden absolute right-0 mt-3 z-50 border border-base-300 bg-base-200 w-64 shadow-pop rounded-hz-surface overflow-hidden"
                >
                  <li class="px-4 py-3 border-b border-base-300">
                    <p class="text-sm font-bold truncate">
                      {@current_user.display_name || "Account"}
                    </p>
                    <p class="mono-label text-base-content/40 mt-0.5 truncate normal-case">
                      {@current_user.email}
                    </p>
                  </li>
                  <li>
                    <a
                      href="/my-huddlz"
                      class="block px-4 py-2.5 text-sm hover:bg-base-300 hover:text-primary transition-colors"
                    >
                      My huddlz
                    </a>
                  </li>
                  <li>
                    <a
                      href="/my-groups"
                      class="block px-4 py-2.5 text-sm hover:bg-base-300 hover:text-primary transition-colors"
                    >
                      My groups
                    </a>
                  </li>
                  <li>
                    <a
                      href="/organize"
                      class="flex items-center justify-between px-4 py-2.5 text-sm font-bold text-primary hover:bg-base-300 transition-colors"
                    >
                      Organizer workspace <span aria-hidden="true">→</span>
                    </a>
                  </li>
                  <li>
                    <a
                      href="/profile"
                      class="block px-4 py-2.5 text-sm hover:bg-base-300 hover:text-primary transition-colors"
                    >
                      Profile &amp; preferences
                    </a>
                  </li>
                  <%= if @current_user.role == :admin do %>
                    <li>
                      <a
                        href="/admin"
                        class="block px-4 py-2.5 text-sm hover:bg-base-300 hover:text-primary transition-colors"
                      >
                        Admin panel
                      </a>
                    </li>
                  <% end %>
                  <li>
                    <a
                      href="/discover"
                      class="block px-4 py-2.5 text-sm hover:bg-base-300 hover:text-primary transition-colors"
                    >
                      Discover huddlz
                    </a>
                  </li>
                  <li class="border-t border-base-300">
                    <.link
                      href="/sign-out"
                      method="delete"
                      class="block px-4 py-2.5 text-sm text-error hover:bg-base-300 transition-colors"
                    >
                      Sign out
                    </.link>
                  </li>
                </ul>
              </div>
            <% else %>
              <a
                href="/register"
                class="inline-flex items-center h-12 px-5 text-sm font-bold border border-base-300 rounded-hz-control text-base-content hover:border-primary hover:text-primary transition-colors"
              >
                Sign Up
              </a>
              <a
                href="/sign-in"
                class="inline-flex items-center h-12 px-5 text-sm font-extrabold bg-primary text-primary-content rounded-hz-control hover:brightness-110 transition-colors"
              >
                Sign In
              </a>
            <% end %>
            <%!-- Mobile menu button --%>
            <button
              type="button"
              class="md:hidden grid place-items-center w-12 h-12 border border-base-300 rounded-hz-control hover:border-primary transition-colors"
              phx-click={JS.toggle(to: "#mobile-menu")}
              aria-label="Open menu"
            >
              <.icon name="hero-bars-3" class="w-5 h-5" />
            </button>
          </div>
        </div>

        <%!-- Search (mobile) --%>
        <form
          method="get"
          action="/discover"
          role="search"
          aria-label="Search huddlz"
          class="md:hidden mb-4 flex items-stretch h-12 border border-base-300 rounded-hz-control overflow-hidden bg-base-200/40 focus-within:border-primary"
        >
          <span
            class="grid place-items-center w-12 text-primary flex-shrink-0 text-lg font-bold select-none"
            aria-hidden="true"
          >
            /
          </span>
          <input
            type="search"
            name="q"
            value={assigns[:search_query] || ""}
            placeholder="Search huddlz"
            aria-label="Search huddlz"
            class="flex-1 min-w-0 border-0 bg-transparent text-base-content text-[15px] focus:outline-none focus:ring-0 placeholder:text-base-content/40"
          />
          <button
            type="submit"
            class="flex-shrink-0 px-4 sm:px-5 bg-primary text-primary-content text-sm font-extrabold"
          >
            Search
          </button>
        </form>

        <%!-- Mobile menu --%>
        <div id="mobile-menu" class="hidden md:hidden border-t border-base-300 py-2 pb-3">
          <a
            href="/organize"
            class="block px-3 py-2 text-sm font-bold hover:bg-base-300 hover:text-primary transition-colors"
          >
            Organize
          </a>
        </div>
      </nav>
    </header>

    <main class="px-6 py-8 sm:px-8 lg:px-12">
      <.flash_group flash={@flash} />
      {render_slot(@inner_block)}
    </main>

    <footer class="border-t border-base-300 px-6 sm:px-8 lg:px-12 mt-12 sm:mt-16 lg:mt-20">
      <div class="py-12 grid grid-cols-2 lg:grid-cols-5 gap-8">
        <div class="col-span-2 lg:col-span-1">
          <p class="text-2xl font-extrabold tracking-tight">huddlz</p>
          <p class="mt-3 text-sm text-base-content/60 max-w-xs">
            Real-life communities, easier to discover and organize.
          </p>
        </div>
        <nav aria-label="Product">
          <h2 class="mono-label text-base-content/40">Product</h2>
          <ul class="mt-3 space-y-2 text-sm font-bold">
            <li>
              <a href="/discover" class="hover:text-primary transition-colors">Discover huddlz</a>
            </li>
            <li>
              <a href="/discover?scope=groups" class="hover:text-primary transition-colors">Groups</a>
            </li>
            <li>
              <a href="/groups/new" class="hover:text-primary transition-colors">Organize</a>
            </li>
          </ul>
        </nav>
        <nav aria-label="Help">
          <h2 class="mono-label text-base-content/40">Help</h2>
          <ul class="mt-3 space-y-2 text-sm font-bold">
            <li><a href="#" class="hover:text-primary transition-colors">Support</a></li>
            <li><a href="#" class="hover:text-primary transition-colors">Contact</a></li>
            <li><a href="#" class="hover:text-primary transition-colors">Status</a></li>
          </ul>
        </nav>
        <nav aria-label="Legal">
          <h2 class="mono-label text-base-content/40">Legal</h2>
          <ul class="mt-3 space-y-2 text-sm font-bold">
            <li><a href="#" class="hover:text-primary transition-colors">Terms</a></li>
            <li><a href="#" class="hover:text-primary transition-colors">Privacy</a></li>
            <li>
              <a href="#" class="hover:text-primary transition-colors">
                Community Guidelines
              </a>
            </li>
            <li>
              <a href="#" class="hover:text-primary transition-colors">Code of Conduct</a>
            </li>
          </ul>
        </nav>
        <nav aria-label="Open">
          <h2 class="mono-label text-base-content/40">Open</h2>
          <ul class="mt-3 space-y-2 text-sm font-bold">
            <li>
              <a
                href="https://github.com/huddlz-hq/huddlz"
                class="hover:text-primary transition-colors"
              >
                GitHub
              </a>
            </li>
            <li>
              <a href="/api/json/swaggerui" class="hover:text-primary transition-colors">
                API docs
              </a>
            </li>
          </ul>
        </nav>
      </div>
      <div class="border-t border-base-300 py-6 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2 text-xs text-base-content/40">
        <p>© 2026 huddlz</p>
        <p>Built for real-life gatherings</p>
      </div>
    </footer>
    """
  end

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

          <div :if={@sidebar_owned_groups != [] or @active == "organize"} class="sb-orgs">
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
              <span class="name">Create group</span>
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
          <%= if @current_user && @current_user.role == :admin do %>
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

  defp first_name(%{display_name: name}) when is_binary(name) do
    case name |> String.trim() |> String.split(~r/\s+/, parts: 2) do
      [first | _] when first != "" -> first
      _ -> "Account"
    end
  end

  defp first_name(_), do: "Account"

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
