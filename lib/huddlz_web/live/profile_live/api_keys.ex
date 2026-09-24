defmodule HuddlzWeb.ProfileLive.ApiKeys do
  @moduledoc """
  API keys page: the person's keys for scripts and AI agents.

  Lists each key with its name, dates and when it was last used. Creating
  a key shows its secret once; after that only its name and dates remain.
  Revoking asks first and deletes the key; an expired key stays listed
  until the person removes it, so a broken agent is explainable.

  Only people with a confirmed address can create keys, so the page and
  its sidebar entry exist only for them.
  """

  use HuddlzWeb, :live_view

  alias Huddlz.Accounts.ApiKey
  alias HuddlzWeb.Layouts

  @expiry_choices [{"30", "30 days"}, {"90", "90 days"}, {"365", "1 year"}]
  @default_expiry "90"

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_required}
  on_mount {HuddlzWeb.LiveUserAuth, :app}

  @impl true
  def mount(_params, _session, socket) do
    case socket.assigns.current_user do
      %{confirmed_at: %DateTime{}} ->
        {:ok,
         socket
         |> assign(:page_title, "API keys")
         |> assign(:mode, :list)
         |> assign(:revoking, nil)
         |> stream_configure(:keys, dom_id: &"api-key-#{&1.id}")
         |> load_keys()}

      _unconfirmed ->
        {:ok,
         socket
         |> put_flash(:error, "Confirm your email address to create API keys.")
         |> push_navigate(to: ~p"/profile")}
    end
  end

  @impl true
  def handle_event("new_key", _params, socket) do
    {:noreply, socket |> assign(:mode, :create) |> assign_form(@default_expiry)}
  end

  def handle_event("cancel", _params, socket) do
    {:noreply, socket |> assign(:mode, :list) |> load_keys()}
  end

  def handle_event("validate", %{"api_key" => params}, socket) do
    {expiry, params} = Map.pop(params, "expires_in_days", @default_expiry)
    form = AshPhoenix.Form.validate(socket.assigns.form, params)
    {:noreply, socket |> assign(:form, form) |> assign(:expiry, expiry)}
  end

  def handle_event("create", %{"api_key" => params}, socket) do
    {expiry, params} = Map.pop(params, "expires_in_days", @default_expiry)
    params = Map.put(params, "expires_at", expires_at(expiry))

    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, key} ->
        {:noreply,
         socket
         |> assign(:mode, {:shown, key.__metadata__.plaintext_api_key, key})}

      {:error, form} ->
        {:noreply, socket |> assign(:form, form) |> assign(:expiry, expiry)}
    end
  end

  # The list leaves the page while a key is being created, so its stream is
  # filled again on the way back.
  def handle_event("done", _params, socket) do
    {:noreply, socket |> assign(:mode, :list) |> load_keys()}
  end

  def handle_event("ask_revoke", %{"id" => id}, socket) do
    case find_key(socket, id) do
      %ApiKey{} = key -> {:noreply, assign(socket, :revoking, key)}
      nil -> {:noreply, socket}
    end
  end

  def handle_event("keep", _params, socket) do
    {:noreply, assign(socket, :revoking, nil)}
  end

  def handle_event("revoke", _params, %{assigns: %{revoking: %ApiKey{} = key}} = socket) do
    {:noreply, socket |> destroy(key) |> assign(:revoking, nil)}
  end

  def handle_event("remove", %{"id" => id}, socket) do
    case find_key(socket, id) do
      %ApiKey{} = key -> {:noreply, destroy(socket, key)}
      nil -> {:noreply, socket}
    end
  end

  defp destroy(socket, key) do
    case Ash.destroy(key, actor: socket.assigns.current_user) do
      :ok ->
        socket |> stream_delete(:keys, key) |> update(:key_count, &(&1 - 1))

      {:error, _error} ->
        put_flash(socket, :error, "That key could not be removed. Try again.")
    end
  end

  # Only the person's own keys are readable, so an id from the page can't
  # reach anyone else's.
  defp find_key(socket, id) do
    case Ash.get(ApiKey, id, actor: socket.assigns.current_user) do
      {:ok, key} -> key
      {:error, _error} -> nil
    end
  end

  defp load_keys(socket) do
    keys =
      ApiKey
      |> Ash.Query.sort(inserted_at: :desc_nils_last)
      |> Ash.read!(actor: socket.assigns.current_user)

    socket
    |> assign(:key_count, length(keys))
    |> stream(:keys, keys, reset: true)
  end

  defp assign_form(socket, expiry) do
    form =
      ApiKey
      |> AshPhoenix.Form.for_create(:create, actor: socket.assigns.current_user, as: "api_key")
      |> to_form()

    socket |> assign(:form, form) |> assign(:expiry, expiry)
  end

  defp expires_at(expiry) do
    days = if expiry in Enum.map(@expiry_choices, &elem(&1, 0)), do: expiry, else: @default_expiry
    DateTime.add(DateTime.utc_now(), String.to_integer(days) * 86_400, :second)
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :expiry_choices, @expiry_choices)

    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      unread_notification_count={@unread_notification_count}
      sidebar_owned_groups={@sidebar_owned_groups}
      active="api_keys"
    >
      <div class="page-head">
        <div>
          <h1>API keys</h1>
          <p>
            Let a script or an AI agent use huddlz as you.
            <.link navigate={~p"/help/agents"}>Connect an agent</.link>
          </p>
        </div>
      </div>

      <div class="settings-stack">
        <.keys_panel :if={@mode == :list} keys={@streams.keys} key_count={@key_count} />
        <.create_panel :if={@mode == :create} form={@form} expiry={@expiry} choices={@expiry_choices} />
        <.shown_panel :if={match?({:shown, _, _}, @mode)} mode={@mode} />
      </div>

      <.revoke_dialog :if={@revoking} key={@revoking} />
    </Layouts.app>
    """
  end

  attr :keys, :any, required: true
  attr :key_count, :integer, required: true

  defp keys_panel(assigns) do
    ~H"""
    <section class="panel api-keys-panel" aria-labelledby="api-keys-title">
      <div class="panel-head">
        <div>
          <h2 id="api-keys-title">Your keys</h2>
          <div class="panel-sub">
            A key acts as you. Each one is shown once and can be revoked any time.
          </div>
        </div>
        <.button id="new-api-key-button" variant={:primary} type="button" phx-click="new_key">
          Create key
        </.button>
      </div>

      <.empty_state :if={@key_count == 0} id="api-keys-empty" icon="hero-key" title="No keys yet">
        Create one when you want an agent or a script to use huddlz for you.
      </.empty_state>

      <ul
        id="api-keys"
        class={["row-list api-key-list", @key_count == 0 && "hidden"]}
        aria-label="Your keys"
        phx-update="stream"
      >
        <li :for={{dom_id, key} <- @keys} id={dom_id} class="row api-key-row">
          <div>
            <div class="api-key-name">
              <h3 class={["row-title", expired?(key) && "muted"]}>{key.name}</h3>
              <.pill :if={expired?(key)} variant={:warn}>Expired</.pill>
            </div>
            <div class="row-desc">{key_meta(key)}</div>
          </div>
          <.button
            :if={!expired?(key)}
            type="button"
            class="btn-sm"
            phx-click="ask_revoke"
            phx-value-id={key.id}
          >
            Revoke
          </.button>
          <.button
            :if={expired?(key)}
            type="button"
            class="btn-sm"
            phx-click="remove"
            phx-value-id={key.id}
          >
            Remove
          </.button>
        </li>
      </ul>
    </section>
    """
  end

  attr :form, Phoenix.HTML.Form, required: true
  attr :expiry, :string, required: true
  attr :choices, :list, required: true

  defp create_panel(assigns) do
    ~H"""
    <.form
      for={@form}
      id="api-key-form"
      class="panel"
      phx-change="validate"
      phx-submit="create"
      aria-labelledby="api-key-form-title"
    >
      <div class="panel-head">
        <div>
          <h2 id="api-key-form-title">Create an API key</h2>
          <div class="panel-sub">
            Name it after where it will live, so you know which one to revoke later.
          </div>
        </div>
      </div>

      <div class="form-grid">
        <.input field={@form[:name]} type="text" label="Name" autocomplete="off" />

        <fieldset class="form-row api-key-expiry">
          <legend class="form-label">Expires after</legend>
          <div class="segmented">
            <label
              :for={{days, label} <- @choices}
              class={["segmented-option", @expiry == days && "on"]}
            >
              <input
                type="radio"
                name="api_key[expires_in_days]"
                value={days}
                checked={@expiry == days}
              />
              {label}
            </label>
          </div>
          <p class="form-help">
            Expires {format_date(
              DateTime.add(DateTime.utc_now(), String.to_integer(@expiry) * 86_400)
            )}. You can revoke it sooner.
          </p>
        </fieldset>
      </div>

      <div class="form-foot">
        <.button variant={:primary} type="submit">Create key</.button>
        <.button type="button" phx-click="cancel">Cancel</.button>
      </div>
    </.form>
    """
  end

  attr :mode, :any, required: true

  defp shown_panel(assigns) do
    {:shown, plaintext, key} = assigns.mode
    assigns = assign(assigns, plaintext: plaintext, key: key)

    ~H"""
    <section class="panel" aria-labelledby="new-api-key-title">
      <div class="panel-head">
        <div>
          <h2 id="new-api-key-title">Copy your new key</h2>
          <div class="panel-sub">{@key.name} · Expires {format_date(@key.expires_at)}</div>
        </div>
      </div>

      <div class="api-key-shown">
        <p class="api-key-warning" role="note">
          This is the only time huddlz shows this key. Paste it into your agent now, or keep it in a password manager. Anyone with it can act as you.
        </p>
        <div class="api-key-secret">
          <div class="api-key-secret-row">
            <.input
              id="new-api-key"
              name="new_api_key"
              label="Your key"
              value={@plaintext}
              class="api-key-value"
              readonly
            />
            <button type="button" id="new-api-key-copy" class="btn-primary" data-value={@plaintext}>
              <span
                id="new-api-key-copy-label"
                phx-hook="ClipboardCopy"
                phx-update="ignore"
                aria-live="polite"
              >
                Copy
              </span>
            </button>
          </div>
        </div>
      </div>

      <div class="form-foot api-key-shown-foot">
        <.button type="button" phx-click="done">Done</.button>
        <.link navigate={~p"/help/agents"}>Next: connect your agent</.link>
      </div>
    </section>
    """
  end

  attr :key, ApiKey, required: true

  defp revoke_dialog(assigns) do
    ~H"""
    <.modal id="revoke-api-key-dialog" show on_cancel={JS.push("keep")}>
      <div class="pr-8">
        <h2 id="revoke-api-key-dialog-title" class="text-xl font-bold">
          Revoke “{@key.name}”?
        </h2>
        <p class="mt-3 muted">
          Anything using this key stops working on its next request. You can't undo this, but you can create a new key.
        </p>
      </div>
      <div class="form-foot mt-6">
        <.button id="revoke-api-key-confirm" type="button" variant={:destructive} phx-click="revoke">
          Revoke
        </.button>
        <.button id="revoke-api-key-keep" type="button" phx-click="keep">Keep key</.button>
      </div>
    </.modal>
    """
  end

  defp expired?(%ApiKey{expires_at: expires_at}),
    do: not DateTime.after?(expires_at, DateTime.utc_now())

  defp key_meta(key) do
    [created_text(key), expiry_text(key), use_text(key)]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" · ")
  end

  # Keys made before creation times were recorded have none; say nothing
  # rather than guess.
  defp created_text(%ApiKey{inserted_at: nil}), do: nil
  defp created_text(%ApiKey{inserted_at: at}), do: "Created #{format_date(at)}"

  defp expiry_text(key) do
    if expired?(key),
      do: "Expired #{format_date(key.expires_at)}",
      else: "Expires #{format_date(key.expires_at)}"
  end

  defp use_text(%ApiKey{last_used_at: nil}), do: "Never used"

  defp use_text(%ApiKey{last_used_at: at} = key) do
    if expired?(key), do: "Last used #{format_date(at)}", else: "Used #{ago(at)}"
  end

  defp ago(at) do
    seconds = DateTime.diff(DateTime.utc_now(), at)

    cond do
      seconds < 60 -> "just now"
      seconds < 3_600 -> plural(div(seconds, 60), "minute") <> " ago"
      seconds < 86_400 -> plural(div(seconds, 3_600), "hour") <> " ago"
      seconds < 30 * 86_400 -> plural(div(seconds, 86_400), "day") <> " ago"
      true -> "on #{format_date(at)}"
    end
  end

  defp plural(1, unit), do: "1 #{unit}"
  defp plural(n, unit), do: "#{n} #{unit}s"

  defp format_date(%DateTime{} = at), do: Calendar.strftime(at, "%-d %b %Y")
end
