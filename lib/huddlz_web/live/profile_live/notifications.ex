defmodule HuddlzWeb.ProfileLive.Notifications do
  @moduledoc """
  Settings page for the user's email notification preferences.

  Renders one toggle per entry in `Huddlz.Notifications.Triggers`, grouped
  by category. Transactional triggers are shown disabled-but-on for
  transparency. Activity and digest triggers are editable. Submitting the
  form merges the changes onto `User.notification_preferences` via the
  `:update_notification_preferences` Ash action.
  """

  use HuddlzWeb, :live_view

  alias Huddlz.Notifications
  alias Huddlz.Notifications.Triggers
  alias HuddlzWeb.Layouts

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_required}
  on_mount {HuddlzWeb.LiveUserAuth, :v3_app}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    {:ok,
     socket
     |> assign(:page_title, "Settings")
     |> assign(:triggers_by_category, group_triggers())
     |> assign(:current_user, user)}
  end

  @impl true
  def handle_event("save", %{"prefs" => prefs_params}, socket) do
    user = socket.assigns.current_user
    preferences = normalize_form_params(prefs_params)

    user
    |> Ash.Changeset.for_update(
      :update_notification_preferences,
      %{preferences: preferences},
      actor: user
    )
    |> Ash.update()
    |> case do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> assign(:current_user, updated_user)
         |> put_flash(:info, "Notification preferences saved")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not save preferences")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.v3_app
      flash={@flash}
      current_user={@current_user}
      sidebar_owned_groups={@sidebar_owned_groups}
      active="settings"
    >
      <div class="page-head">
        <div>
          <h1>Settings</h1>
          <p>Notification preferences and other knobs. We'll add more here as huddlz grows.</p>
        </div>
      </div>

      <form phx-submit="save">
        <.read_only_panel
          title="Transactional"
          description="Critical account and event updates. Always on — these can't be disabled."
          triggers={@triggers_by_category.transactional}
        />

        <.category_panel
          title="Activity"
          description="Things that happen in groups and huddlz you're part of."
          triggers={@triggers_by_category.activity}
          user={@current_user}
        />

        <.category_panel
          title="Digest"
          description="Optional summaries. Off by default."
          triggers={@triggers_by_category.digest}
          user={@current_user}
        />

        <div class="form-foot" style="border:0; margin:0 0 32px">
          <.v3_button variant={:primary} type="submit">Save preferences</.v3_button>
        </div>
      </form>
    </Layouts.v3_app>
    """
  end

  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :triggers, :list, required: true
  attr :user, :any, required: true

  defp category_panel(assigns) do
    ~H"""
    <div class="panel">
      <div class="panel-head">
        <div>
          <h2>{@title}</h2>
          <div class="panel-sub">{@description}</div>
        </div>
      </div>
      <div class="settings-list row-list pref-list">
        <div :for={{trigger, entry} <- @triggers} class="row">
          <div>
            <label class="row-title" for={"prefs-#{Triggers.preference_key(trigger)}"}>
              {entry.label}
            </label>
          </div>
          <label class="toggle">
            <input type="hidden" name={"prefs[#{Triggers.preference_key(trigger)}]"} value="false" />
            <input
              id={"prefs-#{Triggers.preference_key(trigger)}"}
              type="checkbox"
              name={"prefs[#{Triggers.preference_key(trigger)}]"}
              value="true"
              checked={Notifications.preference_for(@user, trigger)}
            />
            <span class="track"></span>
            <span class="toggle-text">
              {if Notifications.preference_for(@user, trigger), do: "On", else: "Off"}
            </span>
          </label>
        </div>
      </div>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :triggers, :list, required: true

  defp read_only_panel(assigns) do
    ~H"""
    <div class="panel">
      <div class="panel-head">
        <div>
          <h2>{@title}</h2>
          <div class="panel-sub">{@description}</div>
        </div>
      </div>
      <div class="settings-list row-list pref-list">
        <div :for={{_trigger, entry} <- @triggers} class="row">
          <div>
            <div class="row-title">{entry.label}</div>
          </div>
          <span class="toggle">
            <input type="checkbox" checked disabled />
            <span class="track"></span>
            <span class="toggle-text">On</span>
          </span>
        </div>
      </div>
    </div>
    """
  end

  defp group_triggers do
    %{
      transactional: sort_entries(Triggers.by_category(:transactional)),
      activity: sort_entries(Triggers.by_category(:activity)),
      digest: sort_entries(Triggers.by_category(:digest))
    }
  end

  defp sort_entries(entries) do
    entries
    |> Enum.sort_by(fn {_atom, entry} -> entry.label end)
  end

  # The form only sends keys for *checked* boxes (we don't render a hidden
  # paired input). Iterate every editable trigger so the saved map stays
  # exhaustive: missing keys become `false`.
  defp normalize_form_params(form_prefs) do
    all_editable_keys =
      Triggers.all()
      |> Enum.reject(fn {_atom, entry} -> entry.category == :transactional end)
      |> Enum.map(fn {atom, _entry} -> Triggers.preference_key(atom) end)

    Enum.into(all_editable_keys, %{}, fn key ->
      {key, Map.get(form_prefs, key) == "true"}
    end)
  end
end
