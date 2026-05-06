defmodule HuddlzWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered as part of the
  application router. The "app" layout is rendered as component
  in regular views and live views.
  """
  use HuddlzWeb, :html

  embed_templates "layouts/*"

  def app(assigns) do
    ~H"""
    <header class="bg-base-100/95 backdrop-blur-sm border-b border-base-300 sticky top-0 z-50 px-6 sm:px-8 lg:px-12">
      <nav>
        <div class="flex h-20 items-center gap-5">
          <%!-- Brand --%>
          <a href="/" class="flex items-center flex-shrink-0">
            <span class="font-display text-2xl tracking-tighter text-glow">huddlz</span>
          </a>

          <%!-- Search (desktop) --%>
          <form
            method="get"
            action="/"
            role="search"
            aria-label="Search huddlz"
            class="hidden md:flex flex-1 max-w-2xl items-stretch h-12 border border-base-300 rounded-md overflow-hidden bg-base-200/40 focus-within:border-primary focus-within:ring-2 focus-within:ring-primary/15 transition-colors"
          >
            <span class="grid place-items-center w-12 text-primary flex-shrink-0">
              <.icon name="hero-magnifying-glass" class="w-5 h-5" />
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
              class="flex-shrink-0 px-6 bg-primary text-primary-content font-display uppercase text-xs font-black tracking-wider hover:bg-primary/90 transition-colors"
            >
              Search
            </button>
          </form>

          <%!-- Right side --%>
          <div class="ml-auto flex items-center gap-3 flex-shrink-0">
            <a
              href="/groups/new"
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
                  class="cursor-pointer flex items-center justify-center w-12 h-12 border border-base-300 rounded-md hover:border-primary transition-colors"
                >
                  <.avatar user={@current_user} size={:sm} />
                </button>
                <ul
                  id="user-menu"
                  role="menu"
                  phx-click-away={JS.hide(to: "#user-menu")}
                  phx-window-keydown={JS.hide(to: "#user-menu")}
                  phx-key="escape"
                  class="hidden absolute right-0 mt-3 z-50 border border-base-300 bg-base-200 w-64 shadow-xl shadow-primary/5 rounded-md overflow-hidden"
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
                      href="/me?tab=huddlz"
                      class="block px-4 py-2.5 text-sm hover:bg-base-300 hover:text-primary transition-colors"
                    >
                      My huddlz
                    </a>
                  </li>
                  <li>
                    <a
                      href="/me?tab=groups"
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
                      href="/"
                      class="block px-4 py-2.5 text-sm hover:bg-base-300 hover:text-primary transition-colors"
                    >
                      Public home
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
                class="inline-flex items-center h-12 px-5 text-sm font-bold border border-base-300 rounded-md text-base-content hover:border-primary hover:text-primary transition-colors"
              >
                Sign Up
              </a>
              <a
                href="/sign-in"
                class="inline-flex items-center h-12 px-5 text-sm font-bold bg-primary text-primary-content rounded-md hover:bg-primary/90 transition-colors"
              >
                Sign In
              </a>
            <% end %>
            <%!-- Mobile menu button --%>
            <button
              type="button"
              class="md:hidden grid place-items-center w-12 h-12 border border-base-300 rounded-md hover:border-primary transition-colors"
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
          action="/"
          role="search"
          aria-label="Search huddlz"
          class="md:hidden pb-4 flex items-stretch h-12 border border-base-300 rounded-md overflow-hidden bg-base-200/40 focus-within:border-primary"
        >
          <span class="grid place-items-center w-12 text-primary flex-shrink-0">
            <.icon name="hero-magnifying-glass" class="w-5 h-5" />
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
            class="flex-shrink-0 px-5 bg-primary text-primary-content font-display uppercase text-xs font-black tracking-wider"
          >
            Search
          </button>
        </form>

        <%!-- Mobile menu --%>
        <div id="mobile-menu" class="hidden md:hidden border-t border-base-300 py-2 pb-3">
          <a
            href="/groups/new"
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

    <footer class="border-t border-base-300 px-6 sm:px-8 lg:px-12">
      <div class="py-6 flex items-center justify-between">
        <span class="text-xs text-base-content/30">huddlz</span>
        <a
          href="https://github.com/huddlz-hq/huddlz"
          class="flex items-center gap-1.5 text-xs text-base-content/30 hover:text-primary transition-colors"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            height="14"
            viewBox="0 0 16 16"
            width="14"
            aria-hidden="true"
          >
            <path
              fill="currentColor"
              d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z"
            >
            </path>
          </svg>
          Contribute on GitHub
        </a>
      </div>
    </footer>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
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
end
