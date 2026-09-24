defmodule HuddlzWeb.HelpLive.Agents do
  @moduledoc """
  Public guide to connecting an AI agent to huddlz over MCP with an API key:
  create a key, add huddlz to the agent (Claude Code, Codex CLI or any
  client that sends a custom header), then ask for something.

  Hosted connectors (Claude.ai, ChatGPT) need OAuth, which is not offered
  yet, so the guide says so rather than listing them.
  """

  use HuddlzWeb, :live_view

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_optional}
  on_mount {HuddlzWeb.LiveUserAuth, :app}

  @clients [{"claude", "Claude Code"}, {"codex", "Codex CLI"}, {"other", "Other clients"}]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Connect an agent")
     |> assign(:client, "claude")
     |> assign(:mcp_url, HuddlzWeb.Endpoint.url() <> "/mcp")}
  end

  @impl true
  def handle_event("client", %{"client" => client}, socket)
      when client in ["claude", "codex", "other"] do
    {:noreply, assign(socket, :client, client)}
  end

  def handle_event("client", _params, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :clients, @clients)

    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      unread_notification_count={@unread_notification_count}
      sidebar_owned_groups={@sidebar_owned_groups}
      active="help"
    >
      <div class="page-head">
        <div>
          <.link navigate={~p"/help"} class="back-link">
            <.icon name="hero-chevron-left" class="size-3.5" /> Help
          </.link>
          <h1>Connect an agent</h1>
          <p>
            Let Claude Code, Codex or another MCP client find huddlz near you and RSVP when you ask.
          </p>
        </div>
      </div>

      <section class="panel agent-guide" aria-label="Setup steps">
        <ol class="agent-steps">
          <li class="agent-step">
            <span class="agent-step-number" aria-hidden="true">1</span>
            <div class="agent-step-body">
              <h2>Create an API key</h2>
              <p>
                Name it after the agent. huddlz shows the key once, so have your agent's settings open.
              </p>
              <.key_action current_user={@current_user} />
            </div>
          </li>

          <li class="agent-step">
            <span class="agent-step-number" aria-hidden="true">2</span>
            <div class="agent-step-body">
              <h2>Add huddlz to your agent</h2>
              <div class="segmented" role="tablist" aria-label="MCP client">
                <button
                  :for={{id, label} <- @clients}
                  id={"agent-client-#{id}"}
                  type="button"
                  role="tab"
                  aria-selected={to_string(@client == id)}
                  aria-controls="agent-client-panel"
                  class={["segmented-option", @client == id && "on"]}
                  phx-click="client"
                  phx-value-client={id}
                >
                  {label}
                </button>
              </div>
              <div id="agent-client-panel" role="tabpanel">
                <.client_setup client={@client} mcp_url={@mcp_url} />
              </div>
            </div>
          </li>

          <li class="agent-step">
            <span class="agent-step-number" aria-hidden="true">3</span>
            <div class="agent-step-body">
              <h2>Ask for something</h2>
              <ul class="agent-prompts">
                <li>“Find a yoga huddl near me Thursday evening”</li>
                <li>“RSVP me to the second one”</li>
                <li>“Cancel my RSVP for Saturday’s hike”</li>
                <li>“Which groups near me run board game nights?”</li>
              </ul>
            </div>
          </li>
        </ol>

        <div class="agent-notes">
          <div>
            <h2>What your agent can do</h2>
            <ul>
              <li>Find huddlz and groups near your home location</li>
              <li>Read a huddl’s or group’s details</li>
              <li>RSVP, cancel, or join a waitlist for you</li>
              <li>Join or leave groups for you</li>
            </ul>
            <p class="muted">
              It sees what you can see on huddlz. Organizing groups and huddlz isn’t part of it yet.
            </p>
          </div>
          <div>
            <h2>Good to know</h2>
            <ul>
              <li>A key acts as you. Don’t paste it into shared files or chats.</li>
              <li>
                Revoke a key from <.link navigate={~p"/profile/api-keys"}>API keys</.link>
                and it stops working right away.
              </li>
              <li>Claude.ai and ChatGPT connectors aren’t supported yet.</li>
            </ul>
          </div>
        </div>
      </section>
    </Layouts.app>
    """
  end

  attr :current_user, :any, required: true

  defp key_action(%{current_user: %{confirmed_at: %DateTime{}}} = assigns) do
    ~H"""
    <div><.link class="btn-secondary" navigate={~p"/profile/api-keys"}>Create a key</.link></div>
    """
  end

  defp key_action(%{current_user: %{}} = assigns) do
    ~H"""
    <p class="muted">
      <.link navigate={~p"/profile"}>Confirm your email address</.link>
      first; keys need a confirmed address.
    </p>
    """
  end

  defp key_action(assigns) do
    ~H"""
    <div><.link class="btn-secondary" navigate={~p"/sign-in"}>Sign in to create a key</.link></div>
    """
  end

  attr :client, :string, required: true
  attr :mcp_url, :string, required: true

  defp client_setup(%{client: "claude"} = assigns) do
    ~H"""
    <p>Put the key in <code>HUDDLZ_API_KEY</code>, then run:</p>
    <.code_block
      id="claude-command"
      label="Copy command"
      code={
        ~s(claude mcp add --transport http huddlz #{@mcp_url} \\\n  --header "Authorization: Bearer $HUDDLZ_API_KEY")
      }
    />
    """
  end

  defp client_setup(%{client: "codex"} = assigns) do
    ~H"""
    <p>
      Put the key in <code>HUDDLZ_API_KEY</code>, then add this to <code>~/.codex/config.toml</code>:
    </p>
    <.code_block
      id="codex-config"
      label="Copy configuration"
      code={~s([mcp_servers.huddlz]\nurl = "#{@mcp_url}"\nbearer_token_env_var = "HUDDLZ_API_KEY")}
    />
    """
  end

  defp client_setup(assigns) do
    ~H"""
    <p>Any client that supports remote MCP servers with a custom header works:</p>
    <dl class="agent-settings">
      <dt>Server URL</dt>
      <dd><code>{@mcp_url}</code></dd>
      <dt>Transport</dt>
      <dd>Streamable HTTP</dd>
      <dt>Header</dt>
      <dd><code>Authorization: Bearer &lt;your key&gt;</code></dd>
    </dl>
    """
  end

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :code, :string, required: true

  defp code_block(assigns) do
    ~H"""
    <div class="agent-code">
      <pre id={@id}><code>{@code}</code></pre>
      <button type="button" class="btn-secondary btn-sm" data-value={@code} aria-label={@label}>
        <span id={"#{@id}-copy"} phx-hook="ClipboardCopy" phx-update="ignore" aria-live="polite">
          Copy
        </span>
      </button>
    </div>
    """
  end
end
