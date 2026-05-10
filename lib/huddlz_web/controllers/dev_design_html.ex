defmodule HuddlzWeb.DevDesignHTML do
  @moduledoc """
  Templates for the design lab clickthrough.

  Each surface is a separate HEEx template that uses the
  `clickthrough_shell/1` function component for the sidebar + topbar.
  """

  use HuddlzWeb, :html

  embed_templates "dev_design_html/*"

  attr :active, :string, required: true, doc: "active surface key, e.g. \"home\""
  attr :query, :string, default: "", doc: "current search query, prefilled in topbar input"
  attr :signed_in, :boolean, default: true, doc: "false renders the no-sidebar signed-out chrome"
  slot :inner_block, required: true

  @chromeless_surfaces ~w[landing sign-in register reset-request reset-confirm email-confirm]

  def clickthrough_shell(assigns) do
    chromeless = assigns.active in @chromeless_surfaces

    assigns =
      assigns
      |> assign(:is_landing, assigns.active == "landing")
      |> assign(:chromeless, chromeless)

    ~H"""
    <body class={[
      "app",
      @is_landing && "is-landing",
      @chromeless && !@is_landing && "is-auth",
      !@chromeless && !@signed_in && "is-signed-out"
    ]}>
      <%= if @chromeless do %>
        {render_slot(@inner_block)}
      <% else %>
        <%= if @signed_in do %>
          <input type="checkbox" id="nav-toggle" class="nav-toggle" />
          <label for="nav-toggle" class="nav-scrim" aria-hidden="true"></label>
          <aside class="sidebar">
            <div class="sidebar-brand">
              <div class="brand-glyph">h</div>
              <div class="brand-text">huddlz</div>
            </div>

            <nav class="sb-nav">
              <a
                class={["sb-item", @active == "explore" && "active"]}
                href="/dev/design/clickthrough/explore"
              >
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
                <span class="label">Explore</span>
              </a>
              <a
                class={["sb-item", @active == "my-huddlz" && "active"]}
                href="/dev/design/clickthrough/my-huddlz"
              >
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
                <span class="label">My huddlz</span>
              </a>
              <a
                class={["sb-item", @active == "my-groups" && "active"]}
                href="/dev/design/clickthrough/my-groups"
              >
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
                <span class="label">My groups</span>
              </a>
              <a
                class={["sb-item", @active == "calendar" && "active"]}
                href="/dev/design/clickthrough/calendar"
              >
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
                <span class="label">My calendar</span>
              </a>

              <div class="sb-orgs">
                <a
                  class={["sb-org-row", String.starts_with?(@active, "organize") && "active"]}
                  href="/dev/design/clickthrough/organize-overview"
                >
                  <div class="group-mark">PE</div>
                  <span class="name">Phoenix Elixir</span>
                </a>
                <%= if String.starts_with?(@active, "organize") do %>
                  <div class="sb-sub">
                    <a
                      class={["sb-sub-item", @active == "organize-overview" && "active"]}
                      href="/dev/design/clickthrough/organize-overview"
                    >
                      Overview
                    </a>
                    <a
                      class={["sb-sub-item", @active == "organize-huddlz" && "active"]}
                      href="/dev/design/clickthrough/organize-huddlz"
                    >
                      Huddlz
                    </a>
                    <a
                      class={["sb-sub-item", @active == "organize-members" && "active"]}
                      href="/dev/design/clickthrough/organize-members"
                    >
                      Members
                    </a>
                  </div>
                <% end %>
                <a class="sb-org-row" href="#sc">
                  <div class="group-mark mark-magenta">SC</div>
                  <span class="name">Sonoran AI Collective</span>
                </a>
                <a class="sb-org-row" href="#tg">
                  <div class="group-mark mark-warm">TG</div>
                  <span class="name">Trail Coffee Crew</span>
                </a>
                <a class="sb-org-row create" href="/dev/design/clickthrough/group-new">
                  <div class="plus-mark">+</div>
                  <span class="name">Create group</span>
                </a>
              </div>
            </nav>

            <div class="sb-account">
              <a
                class={["sb-item", @active == "profile" && "active"]}
                href="/dev/design/clickthrough/profile"
              >
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
                <span class="label">Profile</span>
              </a>
              <a
                class={["sb-item", @active == "settings" && "active"]}
                href="/dev/design/clickthrough/settings"
              >
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
                <span class="label">Settings</span>
              </a>
              <a
                class={["sb-item", @active == "help" && "active"]}
                href="/dev/design/clickthrough/help"
              >
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
                <span class="label">Help</span>
              </a>
            </div>

            <a class="sb-user" href="/dev/design/clickthrough/profile" aria-label="View profile">
              <img class="avatar" src="/dev/design/images/avatar-mw.svg" alt="" />
              <div class="who">
                <div class="name">Micah Woods</div>
                <div class="role">micah@example.com</div>
              </div>
            </a>
          </aside>
        <% end %>

        <main class="main">
          <header class="content-topbar">
            <%= if @signed_in do %>
              <label for="nav-toggle" class="nav-trigger" aria-label="Open navigation">
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
              </label>
            <% else %>
              <a
                class="topbar-brand"
                href="/dev/design/clickthrough/landing"
                aria-label="huddlz home"
              >
                <div class="brand-glyph">h</div>
                <div class="brand-text">huddlz</div>
              </a>
            <% end %>
            <form
              class="topbar-search"
              action="/dev/design/clickthrough/explore"
              method="get"
              role="search"
            >
              <%= if !@signed_in do %>
                <input type="hidden" name="signed_in" value="0" />
              <% end %>
              <span class="lead-key" aria-hidden="true">/</span>
              <input type="search" name="q" placeholder="Search huddlz" value={@query} />
            </form>
            <div class="content-actions">
              <%= if @signed_in do %>
                <a
                  class={["icon-pill", @active == "notifications" && "active"]}
                  href="/dev/design/clickthrough/notifications"
                  aria-label="Notifications"
                >
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
                  <span class="dot"></span>
                </a>
              <% else %>
                <a class="btn-secondary" href="/dev/design/clickthrough/sign-in">Sign in</a>
                <a class="btn-primary" href="/dev/design/clickthrough/register">Sign up</a>
              <% end %>
            </div>
          </header>

          <div class="content-body">
            {render_slot(@inner_block)}
          </div>
        </main>
      <% end %>
    </body>
    """
  end
end
