defmodule HuddlzWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  Reconciled with the search-organize prototype: header search button uses
  Inter heavy weight at sentence case (no Space Mono uppercase); user
  dropdown and mobile menu use rounded-sm corners matching the new theme.
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
            <span class="text-2xl font-extrabold tracking-tight">huddlz</span>
          </a>

          <%!-- Search (desktop) --%>
          <form
            method="get"
            action="/discover"
            role="search"
            aria-label="Search huddlz"
            class="hidden md:flex flex-1 max-w-2xl items-stretch h-12 border border-base-300 rounded-sm overflow-hidden bg-base-200/40 focus-within:border-primary focus-within:ring-2 focus-within:ring-primary/15 transition-colors"
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
              class="flex-shrink-0 px-6 bg-primary text-primary-content text-sm font-extrabold hover:brightness-110 transition-colors"
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
                  class="hidden absolute right-0 mt-3 z-50 border border-base-300 bg-base-200 w-64 shadow-pop rounded overflow-hidden"
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
                class="inline-flex items-center h-12 px-5 text-sm font-bold border border-base-300 rounded-sm text-base-content hover:border-primary hover:text-primary transition-colors"
              >
                Sign Up
              </a>
              <a
                href="/sign-in"
                class="inline-flex items-center h-12 px-5 text-sm font-extrabold bg-primary text-primary-content rounded-sm hover:brightness-110 transition-colors"
              >
                Sign In
              </a>
            <% end %>
            <%!-- Mobile menu button --%>
            <button
              type="button"
              class="md:hidden grid place-items-center w-12 h-12 border border-base-300 rounded-sm hover:border-primary transition-colors"
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
          class="md:hidden pb-4 flex items-stretch h-12 border border-base-300 rounded-sm overflow-hidden bg-base-200/40 focus-within:border-primary"
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
            class="flex-shrink-0 px-5 bg-primary text-primary-content text-sm font-extrabold"
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
              <a href="/groups" class="hover:text-primary transition-colors">Groups</a>
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
end
