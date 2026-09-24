defmodule HuddlzWeb.LandingLive do
  @moduledoc """
  Public landing page at `/`. Anonymous visitors get the pitch, a search bar
  that hands off to Discover, and the how-it-works, agent and organizer
  sections. Authenticated users are redirected to their agenda.
  """
  use HuddlzWeb, :live_view

  on_mount {HuddlzWeb.LiveUserAuth, :redirect_to_me_if_authenticated}

  @interests ["Board games", "Running", "Book clubs", "Climbing", "Language exchange", "Coding"]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "huddlz")
     |> assign(:body_class, "is-landing")
     |> assign(:interests, @interests)
     |> assign(:search, to_form(%{"q" => ""}, as: :search))
     |> assign(:location, nil)
     |> assign(:waiting_query, nil)}
  end

  # A place picked in Near shows at once but its coordinates arrive later.
  # A search submitted in between waits for them, so Discover always opens
  # with the place the visitor sees.
  @impl true
  def handle_event(
        "search",
        %{"search" => %{"q" => query}},
        %{assigns: %{location: :pending}} = socket
      ) do
    {:noreply,
     socket
     |> assign(:search, to_form(%{"q" => query}, as: :search))
     |> assign(:waiting_query, query)}
  end

  def handle_event("search", %{"search" => %{"q" => query}}, socket) do
    {:noreply, push_navigate(socket, to: discover_path(query, socket.assigns.location))}
  end

  @impl true
  def handle_info({:location_pending, "location-autocomplete"}, socket) do
    {:noreply, assign(socket, :location, :pending)}
  end

  def handle_info({:location_selected, "location-autocomplete", location}, socket) do
    case socket.assigns.waiting_query do
      nil -> {:noreply, assign(socket, :location, location)}
      query -> {:noreply, push_navigate(socket, to: discover_path(query, location))}
    end
  end

  def handle_info({:location_cleared, "location-autocomplete"}, socket) do
    {:noreply, assign(socket, location: nil, waiting_query: nil)}
  end

  defp discover_path(query, location) do
    params =
      [{"q", query && String.trim(query)} | location_params(location)]
      |> Enum.reject(fn {_key, value} -> value in [nil, ""] end)

    case params do
      [] -> ~p"/discover"
      params -> ~p"/discover?#{params}"
    end
  end

  defp location_params(nil), do: []

  defp location_params(%{display_text: text, latitude: lat, longitude: lng, time_zone: zone}) do
    [
      {"location", text},
      {"lat", Float.to_string(lat)},
      {"lng", Float.to_string(lng)},
      {"time_zone", zone}
    ]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.flash_group flash={@flash} />

    <header class="land-topbar">
      <.link navigate={~p"/"} class="land-brand">
        <span class="brand-glyph">h</span>
        <span class="brand-text">huddlz</span>
      </.link>
      <nav class="land-nav" aria-label="On this page">
        <a href="#how">How it works</a>
        <a href="#agents">For agents</a>
        <a href="#organizers">For organizers</a>
      </nav>
      <div class="land-account">
        <.link navigate={~p"/sign-in"} class="land-signin">Sign in</.link>
        <.link navigate={~p"/register"} class="btn-primary">Sign up</.link>
      </div>
    </header>

    <main class="land">
      <section class="land-hero">
        <div class="land-hero-copy">
          <span class="land-live"><span class="dot"></span>In person and online, every week</span>
          <h1>
            <span>Stop scrolling.</span>
            <span class="land-h1-marks">
              Start <.faces people={~w(pk sj al rm)} class="is-hero" />
            </span>
            <span>showing up.</span>
          </h1>
          <p class="land-lede">
            huddlz is where local groups post their board game nights, run clubs, language swaps and everything in between. Find one this week, RSVP in a tap, and walk in knowing who else is going.
          </p>

          <div class="land-search">
            <.form for={@search} id="landing-search" phx-submit="search" class="land-search-form">
              <.icon name="hero-magnifying-glass" class="size-5 land-search-icon" />
              <div class="land-search-field is-into">
                <.input
                  field={@search[:q]}
                  type="search"
                  label="Into"
                  placeholder="board games, running, Spanish…"
                  autocomplete="off"
                />
              </div>
              <button
                type="submit"
                class={["btn-primary land-search-submit", @waiting_query && "phx-click-loading"]}
              >
                Find a huddl
              </button>
            </.form>
            <div class="land-search-field is-near">
              <span class="land-search-label" aria-hidden="true">Near</span>
              <.live_component
                module={HuddlzWeb.Live.LocationAutocomplete}
                id="location-autocomplete"
                variant={:filter_pill}
                placeholder="Your city"
                notify_pending
              />
            </div>
          </div>

          <div class="land-interests">
            <span>Try</span>
            <.link
              :for={interest <- @interests}
              navigate={~p"/discover?#{[q: interest]}"}
              class="land-interest"
            >
              {interest}
            </.link>
          </div>

          <ul class="land-promises">
            <li><.icon name="hero-check" class="size-4 land-icon-check" />Free to join</li>
            <li>
              <.icon name="hero-check" class="size-4 land-icon-check" />RSVP without joining a group
            </li>
            <li>
              <.icon name="hero-check" class="size-4 land-icon-check" />An open API for your AI assistant
            </li>
          </ul>
        </div>

        <div class="land-hero-art">
          <div class="land-week" aria-hidden="true">
            <div class="land-week-head">
              <span class="land-eyebrow">Example week</span>
            </div>
            <.week_row
              day="THU"
              date="24"
              scene="board-games"
              title="Board game night"
              meta="7:00 PM · The Loft"
            >
              <:people><.faces people={~w(pk do rm)} /></:people>
              <:count>You and 13 others</:count>
              <:status>
                <span class="land-pill is-going"><span class="dot"></span>Going</span>
              </:status>
            </.week_row>
            <.week_row
              day="SAT"
              date="26"
              scene="riverside-run"
              title="Riverside 5K + coffee"
              meta="8:00 AM · Riverside Park"
            >
              <:people><.faces people={~w(sj tn)} /></:people>
              <:count>22 going</:count>
              <:status><span class="land-pill">RSVP</span></:status>
            </.week_row>
            <.week_row
              day="SUN"
              date="27"
              scene="spanish-online"
              title="Spanish conversation hour"
              meta="6:30 PM · Online"
            >
              <:people><.faces people={~w(al mv jb)} /></:people>
              <:count>9 going</:count>
              <:status><span class="land-pill is-warn">3 spots left</span></:status>
            </.week_row>
          </div>

          <div class="land-chat is-floating" aria-hidden="true">
            <div class="land-chat-source">
              <.icon name="hero-sparkles" class="size-4" />Example chat · your assistant, using huddlz
            </div>
            <div class="land-bubble">Anything low-key Thursday after work?</div>
            <p class="land-reply">
              <strong>Board game night</strong>
              at The Loft fits: Thursday at 7:00 PM, 14 going, beginners welcome. Want me to RSVP?
            </p>
            <div class="land-chat-actions">
              <span class="land-fake-btn is-primary">RSVP me</span>
              <span class="land-fake-btn">Show others</span>
            </div>
          </div>
        </div>
      </section>

      <section id="how" class="land-section">
        <div class="land-section-head">
          <span class="land-eyebrow">How it works</span>
          <h2>From “maybe I should get out more” to in the room.</h2>
        </div>
        <div class="land-steps">
          <article class="land-step">
            <div class="land-step-art" aria-hidden="true">
              <div class="land-mini-search">
                <.icon name="hero-magnifying-glass" class="size-4" />something outdoorsy saturday
              </div>
              <div class="land-mini-row">
                <.scene name="riverside-run" />
                <strong>Riverside 5K + coffee</strong><span>Sat 8 AM</span>
              </div>
              <div class="land-mini-row">
                <.scene name="trail-cleanup" />
                <strong>Trail cleanup at Fox Ridge</strong><span>Sat 10 AM</span>
              </div>
            </div>
            <span class="land-step-num">01</span>
            <h3>Find your thing</h3>
            <p>
              Search by interest, place and time, or pick a date range and whether you'd rather meet online or in person.
            </p>
          </article>
          <article class="land-step">
            <div class="land-step-art is-centered" aria-hidden="true">
              <span class="land-going"><.icon name="hero-check" class="size-4 land-icon-check" />You’re going</span>
              <span class="land-step-note">No need to join the group first</span>
            </div>
            <span class="land-step-num">02</span>
            <h3>RSVP in one tap</h3>
            <p>
              Drop in on a huddl without committing to the group. If it clicks, join later and you’ll never miss the next one.
            </p>
          </article>
          <article class="land-step">
            <div class="land-step-art is-list" aria-hidden="true">
              <div class="land-mini-fact">
                <.icon name="hero-clock" class="size-4" />Thu, Sep 24 · 7:00 PM EDT
              </div>
              <div class="land-mini-fact">
                <.icon name="hero-map-pin" class="size-4" />The Loft, 2nd floor
              </div>
              <div class="land-mini-fact">
                <.faces people={~w(pk sj do)} />Priya, Sam and 12 others
              </div>
            </div>
            <span class="land-step-num">03</span>
            <h3>Show up like a regular</h3>
            <p>
              When, where and who else is going, all on one page. Walking in alone is easier when you already know a few names.
            </p>
          </article>
        </div>
      </section>

      <section id="agents" class="land-section">
        <div class="land-agents">
          <div class="land-agents-copy">
            <span class="land-eyebrow">Bring your agent</span>
            <h2>Ask for plans the way you’d ask a friend.</h2>
            <p>
              Everything you can do on huddlz, an assistant can do too. Our open API lets Claude or any agent you use search huddlz, read the details and RSVP for you.
            </p>
            <ul class="land-prompts">
              <li>“What’s happening tonight within two miles?”</li>
              <li>“Find me a group that goes camping.”</li>
              <li>“RSVP me to the Thursday one.”</li>
            </ul>
            <.link navigate={~p"/help"} class="land-arrow-link">
              Explore the API <.icon name="hero-arrow-right" class="size-4" />
            </.link>
          </div>

          <div class="land-chat" aria-hidden="true">
            <div class="land-bubble">Find me something outdoorsy Saturday morning, not too far.</div>
            <span class="land-tool"><.icon name="hero-wrench" class="size-4" />huddlz · search huddlz</span>
            <p class="land-reply">Two good fits this Saturday:</p>
            <div class="land-results">
              <div class="land-result">
                <.scene name="riverside-run" class="is-md" />
                <div>
                  <strong>Riverside 5K + coffee</strong><span>8:00 AM · Riverside Park · 22 going</span>
                </div>
              </div>
              <div class="land-result">
                <.scene name="trail-cleanup" class="is-md" />
                <div>
                  <strong>Trail cleanup at Fox Ridge</strong><span>10:00 AM · Fox Ridge trailhead · 11 going</span>
                </div>
              </div>
            </div>
            <div class="land-bubble">RSVP me to the 5K.</div>
            <p class="land-reply land-done">
              <span class="land-done-mark"><.icon name="hero-check" class="size-4 land-icon-check" /></span>
              <span>Done. You’re going to <strong>Riverside 5K + coffee</strong>, Saturday at 8:00 AM.</span>
            </p>
          </div>
        </div>
      </section>

      <section id="organizers" class="land-section">
        <div class="land-section-head is-split">
          <div>
            <span class="land-eyebrow">For organizers</span>
            <h2>Run the huddl, not the spreadsheet.</h2>
          </div>
          <.link navigate={~p"/register"} class="btn-secondary land-btn-lg">Start a group</.link>
        </div>
        <div class="land-organize">
          <div class="land-series" aria-hidden="true">
            <div class="land-series-head">
              <.scene name="board-games" class="is-lg" />
              <div>
                <strong>Board game night</strong>
                <span>Tabletop Collective · Every Thursday · 7:00 PM</span>
              </div>
              <span class="land-pill is-outline"><.icon name="hero-arrow-path" class="size-3" />Series</span>
            </div>
            <.series_row date="Thu, Sep 24" fill={75} label="18 of 24 going" />
            <.series_row date="Thu, Oct 1" fill={100} label="Full · 3 waiting" warn />
            <.series_row date="Thu, Oct 8" fill={38} label="9 of 24 going" />
            <div class="land-series-share">
              <span>Share</span>
              <span class="land-share-chip">Copy link</span>
              <span class="land-share-chip">QR code</span>
              <span class="land-share-chip">Bluesky</span>
              <span class="land-share-chip">WhatsApp</span>
              <span class="land-share-chip">More</span>
            </div>
          </div>

          <ul class="land-benefits">
            <li>
              <span class="land-benefit-icon"><.icon name="hero-arrow-path" class="size-5" /></span>
              <div>
                <h3>Weekly, set once</h3>
                <p>
                  Recurring series with room to change a date. Edits keep everyone’s RSVP and tell the people affected.
                </p>
              </div>
            </li>
            <li>
              <span class="land-benefit-icon"><.icon name="hero-user-group" class="size-5" /></span>
              <div>
                <h3>Capacity that fills itself</h3>
                <p>
                  Set a limit and a waitlist takes over. When someone drops out, the next person moves up.
                </p>
              </div>
            </li>
            <li>
              <span class="land-benefit-icon"><.icon name="hero-share" class="size-5" /></span>
              <div>
                <h3>Share it everywhere</h3>
                <p>
                  Ready-made posts for the places your people already are, plus a QR code for the flyer on the café wall.
                </p>
              </div>
            </li>
            <li>
              <span class="land-benefit-icon"><.icon name="hero-chart-bar" class="size-5" /></span>
              <div>
                <h3>See what’s working</h3>
                <p>
                  Your group’s overview shows who’s coming, who’s new and which nights to run again.
                </p>
              </div>
            </li>
          </ul>
        </div>
      </section>

      <section class="land-closing">
        <div class="land-seat" aria-hidden="true">
          <.faces people={~w(pk sj al tn rm mv jb do)} class="is-closing" />
          <span class="land-seat-open">+</span>
        </div>
        <h2>There’s a seat saved for you.</h2>
        <p>Sign up in about a minute. No app to install, and your first huddl could be tonight.</p>
        <div class="land-closing-cta">
          <.link navigate={~p"/register"} class="btn-primary land-btn-lg">Join huddlz</.link>
          <.link navigate={~p"/discover"} class="btn-secondary land-btn-lg">Browse huddlz</.link>
        </div>
      </section>
    </main>

    <footer class="land-foot">
      <span class="land-foot-brand"><span class="brand-glyph">h</span>huddlz</span>
      <span>Real-life communities, easier to find and run.</span>
      <nav aria-label="Footer">
        <.link navigate={~p"/help"}>Help</.link>
        <.link navigate={~p"/code-of-conduct"}>Code of conduct</.link>
        <.link navigate={~p"/privacy"}>Privacy</.link>
        <.link navigate={~p"/terms"}>Terms</.link>
      </nav>
      <span>© 2026 huddlz</span>
    </footer>
    """
  end

  attr :people, :list, required: true, doc: "keys of the portraits in priv/static/images/landing"
  attr :class, :string, default: nil

  defp faces(assigns) do
    ~H"""
    <span class={["land-marks", @class]}>
      <span :for={person <- @people} class="member-mark">
        <img src={~p"/images/landing/#{"person-#{person}.jpg"}"} alt="" loading="lazy" />
      </span>
    </span>
    """
  end

  attr :name, :string, required: true, doc: "key of a huddl cover in priv/static/images/landing"
  attr :class, :string, default: nil

  defp scene(assigns) do
    ~H"""
    <span class={["land-scene", @class]}>
      <img src={~p"/images/landing/#{"huddl-#{@name}.jpg"}"} alt="" loading="lazy" />
    </span>
    """
  end

  attr :day, :string, required: true
  attr :date, :string, required: true
  attr :scene, :string, required: true
  attr :title, :string, required: true
  attr :meta, :string, required: true
  slot :people, required: true
  slot :count, required: true
  slot :status, required: true

  defp week_row(assigns) do
    ~H"""
    <div class="land-week-row">
      <div class="land-week-date"><span>{@day}</span><strong>{@date}</strong></div>
      <.scene name={@scene} class="is-week" />
      <div class="land-week-body">
        <strong>{@title}</strong>
        <span class="land-week-meta">{@meta}</span>
        <span class="land-week-people">{render_slot(@people)}{render_slot(@count)}</span>
      </div>
      {render_slot(@status)}
    </div>
    """
  end

  attr :date, :string, required: true
  attr :fill, :integer, required: true
  attr :label, :string, required: true
  attr :warn, :boolean, default: false

  defp series_row(assigns) do
    ~H"""
    <div class="land-series-row">
      <strong>{@date}</strong>
      <span class="land-bar"><span style={"width: #{@fill}%"}></span></span>
      <span class={["land-series-label", @warn && "is-warn"]}>{@label}</span>
    </div>
    """
  end
end
