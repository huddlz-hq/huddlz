defmodule HuddlzWeb.LandingLive do
  @moduledoc """
  Public landing page at `/`. Anonymous visitors see the v3 hero + value tiles
  + sign-up CTAs. Authenticated users are redirected to their dashboard.
  """
  use HuddlzWeb, :live_view

  on_mount {HuddlzWeb.LiveUserAuth, :redirect_to_me_if_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "huddlz")
     |> assign(:body_class, "is-landing")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.flash_group flash={@flash} />

    <header class="land-topbar">
      <a href={~p"/"} style="display:flex;align-items:center;gap:10px">
        <div class="brand-glyph">h</div>
        <div class="brand-text">huddlz</div>
      </a>
      <nav class="nav">
        <.link navigate={~p"/sign-in"} class="btn-secondary">Sign in</.link>
        <.link navigate={~p"/register"} class="btn-primary">Sign up</.link>
      </nav>
    </header>

    <section class="land-hero">
      <span class="eyebrow">In-person and online · everywhere</span>
      <h1>
        <span>Find your people.</span>
        <span>Run the huddl.</span>
      </h1>
      <p>
        huddlz is a calmer home for communities and the huddlz that bring them together. Discover what fits, keep RSVPs organized, and give your group one place to gather.
      </p>
      <div class="land-cta">
        <.link navigate={~p"/discover"} class="btn-primary">Browse huddlz</.link>
        <.link navigate={~p"/register"} class="btn-secondary">Start a group</.link>
      </div>
    </section>

    <section class="land-features">
      <div class="feat">
        <span class="feat-mark">
          <svg
            width="18"
            height="18"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="1.8"
            stroke-linecap="round"
          >
            <circle cx="11" cy="11" r="7" /><path d="m20 20-3.5-3.5" />
          </svg>
        </span>
        <h3>Discovery that learns you</h3>
        <p>
          Search by interest, place, time, or a plain-language idea. Save the search and hear when a matching huddl appears.
        </p>
      </div>
      <div class="feat">
        <span class="feat-mark">
          <svg
            width="18"
            height="18"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="1.8"
            stroke-linecap="round"
            stroke-linejoin="round"
          >
            <path d="M3 11.5 12 4l9 7.5" /><path d="M5 10v10h14V10" />
          </svg>
        </span>
        <h3>Organize without the spreadsheet</h3>
        <p>
          Publish one-off or recurring huddlz, manage capacity and waitlists, invite members, and keep every RSVP together.
        </p>
      </div>
      <div class="feat">
        <span class="feat-mark">
          <svg
            width="18"
            height="18"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="1.8"
            stroke-linecap="round"
            stroke-linejoin="round"
          >
            <path d="M21 11.5a8.4 8.4 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.5 8.5 0 0 1-3.8-.9L3 21l1.9-5.7a8.4 8.4 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.4 8.4 0 0 1 3.8-.9h.5A8.4 8.4 0 0 1 21 11v.5z" />
          </svg>
        </span>
        <h3>Bring your agent</h3>
        <p>
          Ask your LLM to find a huddl, check the details, RSVP, or add it to your schedule through MCP and API tools.
        </p>
      </div>
    </section>

    <footer class="land-foot">
      © 2026 huddlz · real-life communities, easier to discover and organize
    </footer>
    """
  end
end
