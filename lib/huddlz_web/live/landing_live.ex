defmodule HuddlzWeb.LandingLive do
  @moduledoc """
  Public landing page at `/`. Anonymous visitors see the pitch + a preview
  of upcoming huddlz + an organizer hand-off. Authenticated users are
  redirected to their personal dashboard at `/me`.
  """
  use HuddlzWeb, :live_view

  alias Huddlz.Communities
  alias HuddlzWeb.Layouts

  @preview_limit 3
  @huddl_card_loads [:status, :rsvp_count, :visible_virtual_link, :display_image_url, :group]

  on_mount {HuddlzWeb.LiveUserAuth, :redirect_to_me_if_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "huddlz")
     |> assign(:upcoming_preview, load_preview())}
  end

  defp load_preview do
    case Communities.search_huddlz(nil, :upcoming, nil, nil, nil, nil, nil, :soonest,
           page: [limit: @preview_limit, count: false],
           load: @huddl_card_loads,
           authorize?: false
         ) do
      {:ok, %{results: results}} -> results
      _ -> []
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-16 lg:space-y-24">
        <section class="grid gap-10 lg:grid-cols-[3fr_2fr] lg:items-end">
          <div>
            <span class="mono-label text-primary/70">// Find your people, fast</span>
            <h1 class="mt-3 font-display text-4xl sm:text-5xl tracking-tight text-glow leading-[1.05]">
              Find your next real-life gathering.
            </h1>
            <p class="mt-5 max-w-xl text-base-content/70 text-lg leading-relaxed">
              Huddlz helps people discover local huddlz and groups without turning the first step into paperwork. Search for what you want, pick a huddl, and show up.
            </p>
            <div class="mt-8 flex flex-wrap gap-3">
              <.link
                href={~p"/discover"}
                class="inline-flex items-center justify-center h-12 px-6 bg-primary text-primary-content font-display uppercase text-xs font-black tracking-wider hover:bg-primary/90 transition-colors"
              >
                Search huddlz
              </.link>
              <.link
                href={~p"/groups/new"}
                class="inline-flex items-center justify-center h-12 px-6 border border-base-300 text-sm font-bold text-base-content/80 hover:border-primary hover:text-primary transition-colors"
              >
                Organize
              </.link>
            </div>
          </div>
        </section>

        <section class="grid gap-6 sm:grid-cols-3">
          <div class="border border-base-300 p-6">
            <h2 class="font-display text-lg tracking-tight text-glow">Discover quickly</h2>
            <p class="mt-2 text-sm text-base-content/60">
              Search huddlz and groups from the header. Type a topic, city, or community and press Enter.
            </p>
          </div>
          <div class="border border-base-300 p-6">
            <h2 class="font-display text-lg tracking-tight text-glow">Meet in real life</h2>
            <p class="mt-2 text-sm text-base-content/60">
              Huddlz puts the focus on gatherings, RSVPs, location, and the small details that help people show up.
            </p>
          </div>
          <div class="border border-base-300 p-6">
            <h2 class="font-display text-lg tracking-tight text-glow">Organize without clutter</h2>
            <p class="mt-2 text-sm text-base-content/60">
              Organizers get a dedicated workspace for groups, huddlz, attendees, members, messages, and settings.
            </p>
          </div>
        </section>

        <section :if={@upcoming_preview != []} aria-labelledby="upcoming-heading">
          <div class="flex items-baseline justify-between gap-4">
            <h2
              id="upcoming-heading"
              class="font-display text-2xl tracking-tight text-glow flex items-baseline gap-3"
            >
              <span class="mono-label text-primary/70">// Upcoming huddlz</span>
            </h2>
            <.link
              navigate={~p"/discover"}
              class="text-xs text-primary hover:underline font-medium tracking-wide uppercase"
            >
              See all →
            </.link>
          </div>
          <div class="mt-6 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
            <%= for huddl <- @upcoming_preview do %>
              <.huddl_card huddl={huddl} show_group={true} />
            <% end %>
          </div>
        </section>

        <section class="border border-base-300 p-8 lg:p-10">
          <div class="grid gap-10 lg:grid-cols-[3fr_2fr]">
            <div>
              <span class="mono-label text-primary/70">// For organizers</span>
              <h2 class="mt-3 font-display text-3xl tracking-tight text-glow">
                Run the community, not the tooling.
              </h2>
              <p class="mt-4 text-base-content/70 leading-relaxed">
                Organize should lead to a signed-in workspace for creating groups and huddlz, managing RSVPs, checking attendees in, messaging people, and keeping settings sane.
              </p>
              <div class="mt-6">
                <.link
                  href={~p"/groups/new"}
                  class="inline-flex items-center justify-center h-12 px-6 bg-primary text-primary-content font-display uppercase text-xs font-black tracking-wider hover:bg-primary/90 transition-colors"
                >
                  Open organize
                </.link>
              </div>
            </div>
            <ul class="space-y-4">
              <li>
                <p class="font-bold text-sm text-base-content">Create groups and huddlz</p>
                <p class="mt-1 text-sm text-base-content/60">
                  Draft, publish, duplicate, and manage the core gathering details.
                </p>
              </li>
              <li>
                <p class="font-bold text-sm text-base-content">Track attendees and members</p>
                <p class="mt-1 text-sm text-base-content/60">
                  Separate huddl RSVPs from group relationships so each job has a clear home.
                </p>
              </li>
              <li>
                <p class="font-bold text-sm text-base-content">Communicate clearly</p>
                <p class="mt-1 text-sm text-base-content/60">
                  Send announcements, reminders, and direct follow-ups from one operations surface.
                </p>
              </li>
            </ul>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
