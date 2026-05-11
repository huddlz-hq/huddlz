defmodule HuddlzWeb.HelpLive do
  @moduledoc """
  Help center at `/help` — FAQ, contact, apps, developer resources, follow,
  legal, and about. Visible to both anonymous visitors and signed-in users;
  rendered inside the v3 app shell so signed-in users see the sidebar.

  Content is currently placeholder copy from the clickthrough mockup. Real
  content (linked support, status, docs) lands as separate small PRs as
  those destinations come online.
  """
  use HuddlzWeb, :live_view

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_optional}
  on_mount {HuddlzWeb.LiveUserAuth, :v3_app}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Help")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.v3_app
      flash={@flash}
      current_user={@current_user}
      sidebar_owned_groups={@sidebar_owned_groups}
      active="help"
    >
      <div class="page-head">
        <div>
          <h1>Help</h1>
          <p>
            Answers, links, and the legal stuff. If you can't find what you're looking for, drop us a line.
          </p>
        </div>
      </div>

      <.v3_panel>
        <:head>
          <h2>Frequently asked</h2>
        </:head>
        <div class="settings-list row-list">
          <.v3_list_row>
            <div>
              <div class="row-title">How do I create a group?</div>
              <div class="row-desc">Use "Create group" in the sidebar — anyone can spin one up.</div>
            </div>
            <.v3_pill>Read</.v3_pill>
          </.v3_list_row>
          <.v3_list_row>
            <div>
              <div class="row-title">What's a huddl?</div>
              <div class="row-desc">Our word for an event — meetup, workshop, social, anything.</div>
            </div>
            <.v3_pill>Read</.v3_pill>
          </.v3_list_row>
          <.v3_list_row>
            <div>
              <div class="row-title">Recurring huddlz, capacity, and the waitlist</div>
              <div class="row-desc">How scheduling and RSVPs actually work.</div>
            </div>
            <.v3_pill>Read</.v3_pill>
          </.v3_list_row>
          <.v3_list_row>
            <div>
              <div class="row-title">Agents, MCP, and the API</div>
              <div class="row-desc">
                How to plug huddlz into Claude, ChatGPT, or your own tooling.
              </div>
            </div>
            <.v3_pill>Read</.v3_pill>
          </.v3_list_row>
        </div>
      </.v3_panel>

      <.v3_panel>
        <:head>
          <h2>Contact us</h2>
        </:head>
        <div class="settings-list row-list">
          <.v3_list_row>
            <div>
              <div class="row-title">Email support</div>
              <div class="row-desc">
                support@huddlz.example — we read everything, reply within a day or two.
              </div>
            </div>
            <.v3_pill>Email</.v3_pill>
          </.v3_list_row>
          <.v3_list_row>
            <div>
              <div class="row-title">Report a bug</div>
              <div class="row-desc">Issue tracker on GitHub — public, low-friction.</div>
            </div>
            <.v3_pill>Open</.v3_pill>
          </.v3_list_row>
          <.v3_list_row>
            <div>
              <div class="row-title">Status &amp; uptime</div>
              <div class="row-desc">Live system status — incidents, scheduled maintenance.</div>
            </div>
            <.v3_pill variant={:cyan}>All systems normal</.v3_pill>
          </.v3_list_row>
        </div>
      </.v3_panel>

      <.v3_panel>
        <:head>
          <div>
            <h2>Apps</h2>
            <div class="panel-sub">
              Native apps are in the works — sign up to be notified when they ship.
            </div>
          </div>
        </:head>
        <div class="settings-list row-list">
          <.v3_list_row>
            <div>
              <div class="row-title">huddlz for iOS</div>
              <div class="row-desc">App Store · in development</div>
            </div>
            <.v3_pill variant={:muted}>Coming soon</.v3_pill>
          </.v3_list_row>
          <.v3_list_row>
            <div>
              <div class="row-title">huddlz for Android</div>
              <div class="row-desc">Google Play · in development</div>
            </div>
            <.v3_pill variant={:muted}>Coming soon</.v3_pill>
          </.v3_list_row>
          <.v3_list_row>
            <div>
              <div class="row-title">Notify me</div>
              <div class="row-desc">We'll email when builds are public.</div>
            </div>
            <.v3_pill>Subscribe</.v3_pill>
          </.v3_list_row>
        </div>
      </.v3_panel>

      <.v3_panel>
        <:head>
          <div>
            <h2>Developers</h2>
            <div class="panel-sub">
              huddlz is API-first — every action you can take in the UI is reachable via API and MCP.
            </div>
          </div>
        </:head>
        <div class="settings-list row-list">
          <.v3_list_row>
            <div>
              <div class="row-title">API documentation</div>
              <div class="row-desc">REST + GraphQL · authentication, schemas, examples.</div>
            </div>
            <.v3_pill>Open</.v3_pill>
          </.v3_list_row>
          <.v3_list_row>
            <div>
              <div class="row-title">MCP server</div>
              <div class="row-desc">
                Drop-in tool integration for Claude Desktop and other agents.
              </div>
            </div>
            <.v3_pill>Setup</.v3_pill>
          </.v3_list_row>
          <.v3_list_row>
            <div>
              <div class="row-title">Source code on GitHub</div>
              <div class="row-desc">
                github.com/huddlz-hq · open source, contributions welcome.
              </div>
            </div>
            <.v3_pill>Open</.v3_pill>
          </.v3_list_row>
          <.v3_list_row>
            <div>
              <div class="row-title">Changelog</div>
              <div class="row-desc">What shipped, when, and what broke.</div>
            </div>
            <.v3_pill>Read</.v3_pill>
          </.v3_list_row>
        </div>
      </.v3_panel>

      <.v3_panel>
        <:head>
          <div>
            <h2>Follow huddlz</h2>
            <div class="panel-sub">
              Keep up with releases, events worth knowing about, and the occasional dev rant.
            </div>
          </div>
        </:head>
        <div class="settings-list row-list">
          <.v3_list_row>
            <div>
              <div class="row-title">Bluesky</div>
              <div class="row-desc">@huddlz.bsky.social — the most active channel.</div>
            </div>
            <.v3_pill>Follow</.v3_pill>
          </.v3_list_row>
          <.v3_list_row>
            <div>
              <div class="row-title">Mastodon</div>
              <div class="row-desc">@huddlz@indieweb.social</div>
            </div>
            <.v3_pill>Follow</.v3_pill>
          </.v3_list_row>
          <.v3_list_row>
            <div>
              <div class="row-title">X / Twitter</div>
              <div class="row-desc">@huddlzhq — release notes mirror.</div>
            </div>
            <.v3_pill>Follow</.v3_pill>
          </.v3_list_row>
          <.v3_list_row>
            <div>
              <div class="row-title">LinkedIn</div>
              <div class="row-desc">Company page · jobs, longer-form posts.</div>
            </div>
            <.v3_pill>Follow</.v3_pill>
          </.v3_list_row>
        </div>
      </.v3_panel>

      <.v3_panel>
        <:head>
          <h2>Legal</h2>
        </:head>
        <div class="settings-list row-list">
          <.v3_list_row>
            <div>
              <div class="row-title">Code of Conduct</div>
              <div class="row-desc">How we expect everyone to treat each other on huddlz.</div>
            </div>
            <.v3_pill>Read</.v3_pill>
          </.v3_list_row>
          <.v3_list_row>
            <div>
              <div class="row-title">Community guidelines</div>
              <div class="row-desc">What's allowed on the platform — content, groups, huddlz.</div>
            </div>
            <.v3_pill>Read</.v3_pill>
          </.v3_list_row>
          <.v3_list_row>
            <div>
              <div class="row-title">Terms of Service</div>
              <div class="row-desc">The agreement between you and huddlz.</div>
            </div>
            <.v3_pill>Read</.v3_pill>
          </.v3_list_row>
          <.v3_list_row>
            <div>
              <div class="row-title">Privacy policy</div>
              <div class="row-desc">What we collect, what we don't, and what we do with it.</div>
            </div>
            <.v3_pill>Read</.v3_pill>
          </.v3_list_row>
          <.v3_list_row>
            <div>
              <div class="row-title">Cookies</div>
              <div class="row-desc">Session cookies only · no tracking pixels.</div>
            </div>
            <.v3_pill>Read</.v3_pill>
          </.v3_list_row>
        </div>
      </.v3_panel>

      <.v3_panel>
        <:head>
          <h2>About huddlz</h2>
        </:head>
        <div class="settings-list row-list">
          <.v3_list_row>
            <div>
              <div class="row-title">Real-life communities, easier to discover and organize</div>
              <div class="row-desc">
                Built for real-life gatherings — small enough to feel personal, ambitious enough to be useful.
              </div>
            </div>
            <.v3_pill>Mission</.v3_pill>
          </.v3_list_row>
          <.v3_list_row>
            <div>
              <div class="row-title">© 2026 huddlz</div>
              <div class="row-desc">All rights reserved.</div>
            </div>
            <.v3_pill variant={:muted}>Copyright</.v3_pill>
          </.v3_list_row>
        </div>
      </.v3_panel>
    </Layouts.v3_app>
    """
  end
end
