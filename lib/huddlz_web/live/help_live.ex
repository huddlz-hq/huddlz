defmodule HuddlzWeb.HelpLive do
  @moduledoc """
  Public help directory with only working support, developer, legal, and source
  destinations.
  """

  use HuddlzWeb, :live_view

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_optional}
  on_mount {HuddlzWeb.LiveUserAuth, :app}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Help")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      sidebar_owned_groups={@sidebar_owned_groups}
      active="help"
    >
      <div class="page-head help-page-head">
        <div>
          <h1>Help</h1>
          <p>Get support, explore the APIs, or read the policies that keep huddlz useful.</p>
        </div>
      </div>

      <div id="help-directory" class="help-directory">
        <.panel id="help-support">
          <:head>
            <div>
              <h2>Support</h2>
              <div class="panel-sub">Talk to a person or report something that needs fixing.</div>
            </div>
          </:head>
          <div class="settings-list row-list">
            <a class="row help-link-row" href="mailto:support@huddlz.com">
              <div>
                <div class="row-title">Email support</div>
                <div class="row-desc">support@huddlz.com</div>
              </div>
              <.pill>Email</.pill>
            </a>
            <a
              class="row help-link-row"
              href="https://github.com/huddlz-hq/huddlz/issues"
              target="_blank"
              rel="noopener noreferrer"
            >
              <div>
                <div class="row-title">Report a bug on GitHub</div>
                <div class="row-desc">Open an issue in the public huddlz repository.</div>
              </div>
              <.pill>GitHub ↗</.pill>
            </a>
          </div>
        </.panel>

        <.panel id="help-developers">
          <:head>
            <div>
              <h2>Developers</h2>
              <div class="panel-sub">Use the interfaces that are available today.</div>
            </div>
          </:head>
          <div class="settings-list row-list">
            <a
              class="row help-link-row"
              href={~p"/api/json/swaggerui"}
              target="_blank"
              rel="noopener"
            >
              <div>
                <div class="row-title">JSON:API explorer</div>
                <div class="row-desc">Browse the OpenAPI schema and available JSON endpoints.</div>
              </div>
              <.pill>Explore ↗</.pill>
            </a>
            <a
              class="row help-link-row"
              href={~p"/gql/playground"}
              target="_blank"
              rel="noopener"
            >
              <div>
                <div class="row-title">GraphQL playground</div>
                <div class="row-desc">Inspect the schema and run GraphQL operations.</div>
              </div>
              <.pill>Open ↗</.pill>
            </a>
            <a
              class="row help-link-row"
              href="https://github.com/huddlz-hq/huddlz"
              target="_blank"
              rel="noopener noreferrer"
            >
              <div>
                <div class="row-title">Source code</div>
                <div class="row-desc">
                  Read the code, follow development, or contribute on GitHub.
                </div>
              </div>
              <.pill>GitHub ↗</.pill>
            </a>
          </div>
        </.panel>

        <.panel id="help-legal">
          <:head>
            <div>
              <h2>Legal and community</h2>
              <div class="panel-sub">The rules, responsibilities, and privacy commitments.</div>
            </div>
          </:head>
          <div class="settings-list row-list">
            <.link navigate={~p"/terms"} class="row help-link-row">
              <div>
                <div class="row-title">Terms of Service</div>
                <div class="row-desc">The agreement governing use of huddlz.</div>
              </div>
              <.pill>Read →</.pill>
            </.link>
            <.link navigate={~p"/code-of-conduct"} class="row help-link-row">
              <div>
                <div class="row-title">Code of Conduct</div>
                <div class="row-desc">How people are expected to treat each other.</div>
              </div>
              <.pill>Read →</.pill>
            </.link>
            <.link navigate={~p"/privacy"} class="row help-link-row">
              <div>
                <div class="row-title">Privacy Policy</div>
                <div class="row-desc">What huddlz collects, uses, shares, and retains.</div>
              </div>
              <.pill>Read →</.pill>
            </.link>
          </div>
        </.panel>

        <.panel id="help-about">
          <:head>
            <h2>About huddlz</h2>
          </:head>
          <div class="help-mission">
            <p>Real-life communities, easier to discover and organize.</p>
            <span>Built for gatherings small enough to feel personal and useful enough to last.</span>
          </div>
          <footer class="help-copyright">© 2026 huddlz. All rights reserved.</footer>
        </.panel>
      </div>
    </Layouts.app>
    """
  end
end
