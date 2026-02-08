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
    <header class="bg-base-100/95 backdrop-blur-sm border-b border-base-300 sticky top-0 z-50 px-4 sm:px-6 lg:px-8">
      <nav class="mx-auto max-w-6xl">
        <div class="flex h-14 items-center justify-between">
          <%!-- Logo + nav links --%>
          <div class="flex items-center gap-8">
            <a href="/" class="flex items-center group">
              <span class="font-display text-lg tracking-tighter text-glow">huddlz</span>
            </a>
            <div class="hidden md:flex items-center gap-1">
              <a
                href="/groups"
                class="px-3 py-1.5 text-sm font-medium text-base-content/50 hover:text-primary transition-colors"
              >
                Groups
              </a>
            </div>
          </div>

          <%!-- Right side --%>
          <div class="flex items-center gap-3">
            <%= if @current_user do %>
              <div class="dropdown dropdown-end">
                <label tabindex="0" class="cursor-pointer">
                  <div class="ring-1 ring-base-300 hover:ring-primary transition-colors">
                    <.avatar user={@current_user} size={:sm} />
                  </div>
                </label>
                <ul
                  tabindex="0"
                  class="dropdown-content mt-3 z-[1] p-1 border border-primary/20 bg-base-200 w-56 shadow-xl shadow-primary/5"
                >
                  <li class="px-3 py-2.5 border-b border-base-300">
                    <span class="mono-label text-primary/60">
                      Signed in as
                    </span>
                    <p class="text-sm font-medium truncate mt-0.5">
                      {@current_user.display_name || @current_user.email}
                    </p>
                  </li>
                  <li>
                    <a
                      href="/profile"
                      class="flex items-center gap-2 px-3 py-2 text-sm hover:bg-base-300 hover:text-primary transition-colors"
                    >
                      <.icon name="hero-user" class="w-4 h-4 text-base-content/40" /> Profile
                    </a>
                  </li>
                  <%= if @current_user.role == :admin do %>
                    <li>
                      <a
                        href="/admin"
                        class="flex items-center gap-2 px-3 py-2 text-sm hover:bg-base-300 hover:text-primary transition-colors"
                      >
                        <.icon name="hero-shield-check" class="w-4 h-4 text-base-content/40" />
                        Admin Panel
                      </a>
                    </li>
                  <% end %>
                  <li class="border-t border-base-300 mt-1 pt-1">
                    <a
                      href="/sign-out"
                      class="flex items-center gap-2 px-3 py-2 text-sm hover:bg-base-300 text-error transition-colors"
                    >
                      <.icon name="hero-arrow-right-on-rectangle" class="w-4 h-4" /> Sign Out
                    </a>
                  </li>
                </ul>
              </div>
            <% else %>
              <a
                href="/register"
                class="px-4 py-1.5 text-sm font-medium border border-base-300 hover:border-primary hover:text-primary btn-neon transition-colors"
              >
                Sign Up
              </a>
              <a
                href="/sign-in"
                class="px-4 py-1.5 text-sm font-medium bg-primary text-primary-content btn-neon"
              >
                Sign In
              </a>
            <% end %>
            <%!-- Mobile menu button --%>
            <button
              class="md:hidden p-1.5 hover:bg-base-300 transition-colors"
              onclick="document.getElementById('mobile-menu').classList.toggle('hidden')"
            >
              <.icon name="hero-bars-3" class="w-5 h-5" />
            </button>
          </div>
        </div>
        <%!-- Mobile menu --%>
        <div id="mobile-menu" class="hidden md:hidden border-t border-base-300 py-2 pb-3">
          <a href="/groups" class="block px-3 py-2 text-sm hover:bg-base-300 hover:text-primary">
            Groups
          </a>
        </div>
      </nav>
    </header>

    <main class="px-4 py-8 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-6xl">
        <.flash_group flash={@flash} />
        {render_slot(@inner_block)}
      </div>
    </main>

    <footer class="border-t border-base-300 px-4 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-6xl py-6 flex items-center justify-between">
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
