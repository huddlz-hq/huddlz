defmodule HuddlzWeb.ProfileLive.Notifications do
  @moduledoc """
  Notifications page: the user's email notification preferences.

  Renders one switch per activity entry in `Huddlz.Notifications.Triggers`.
  Each switch saves as soon as it is flipped, merging that one key onto
  `User.notification_preferences` through the
  `:update_notification_preferences` action, and the row confirms with a
  fading "Saved". Transactional triggers are listed as always sent, without
  controls.

  Digest triggers are registered but have no senders yet (issue #561), so
  the page hides them rather than offering switches that do nothing. Saved
  digest preferences are kept for when they ship.
  """

  use HuddlzWeb, :live_view

  import HuddlzWeb.Components.Input, only: [toggle: 1]

  alias Huddlz.Notifications
  alias Huddlz.Notifications.Triggers
  alias HuddlzWeb.Layouts

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_required}
  on_mount {HuddlzWeb.LiveUserAuth, :app}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    {:ok,
     socket
     |> assign(:page_title, "Notifications")
     |> assign(:triggers_by_category, group_triggers())
     |> assign(:current_user, user)
     |> assign(:form, preferences_form(user))
     |> assign(:saved, nil)
     |> assign(:failed, nil)
     |> assign(:save_seq, 0)}
  end

  @impl true
  def handle_event("toggle", %{"_target" => ["prefs", key], "prefs" => prefs}, socket) do
    user = socket.assigns.current_user
    enabled = Map.get(prefs, key) == "true"

    user
    |> Ash.Changeset.for_update(
      :update_notification_preferences,
      %{preferences: %{key => enabled}},
      actor: user
    )
    |> Ash.update()
    |> case do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> assign(:current_user, updated_user)
         |> assign(:form, preferences_form(updated_user))
         |> assign(:saved, key)
         |> assign(:failed, nil)
         |> update(:save_seq, &(&1 + 1))}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(:form, preferences_form(user))
         |> assign(:saved, nil)
         |> assign(:failed, key)}
    end
  end

  def handle_event("toggle", _params, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      unread_notification_count={@unread_notification_count}
      sidebar_owned_groups={@sidebar_owned_groups}
      active="preferences"
    >
      <div class="page-head">
        <div>
          <h1>Notifications</h1>
          <p>Choose which emails huddlz sends you. Changes save as you flip them.</p>
        </div>
      </div>

      <form id="notification-preferences" phx-change="toggle" class="settings-stack">
        <.category_panel
          title="Activity"
          description="Things that happen in groups and huddlz you're part of."
          triggers={@triggers_by_category.activity}
          form={@form}
          saved={@saved}
          failed={@failed}
          save_seq={@save_seq}
        />

        <.always_sent_panel triggers={@triggers_by_category.transactional} />
      </form>
    </Layouts.app>
    """
  end

  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :triggers, :list, required: true
  attr :form, Phoenix.HTML.Form, required: true
  attr :saved, :string, default: nil
  attr :failed, :string, default: nil
  attr :save_seq, :integer, required: true

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
        <div :for={{trigger, entry} <- @triggers} class="row pref-row">
          <label class="row-title" for={@form[Triggers.preference_key(trigger)].id}>
            {entry.label}
          </label>
          <div class="pref-control">
            <span
              :if={@saved == Triggers.preference_key(trigger)}
              id={"pref-saved-#{Triggers.preference_key(trigger)}-#{@save_seq}"}
              class="pref-saved"
              role="status"
            >
              Saved
            </span>
            <span :if={@failed == Triggers.preference_key(trigger)} class="pref-failed" role="alert">
              Couldn't save. Try again.
            </span>
            <.toggle
              field={@form[Triggers.preference_key(trigger)]}
              label={entry.label}
              labelled_externally
            />
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :triggers, :list, required: true

  defp always_sent_panel(assigns) do
    ~H"""
    <div class="panel">
      <div class="panel-head">
        <div>
          <h2>Always sent</h2>
          <div class="panel-sub">Account and huddl essentials. These go out no matter what.</div>
        </div>
      </div>
      <ul id="always-sent" class="always-sent">
        <li :for={{_trigger, entry} <- @triggers}>
          <.icon name="hero-lock-closed" class="size-4" />
          <span>{entry.label}</span>
        </li>
      </ul>
    </div>
    """
  end

  defp preferences_form(user) do
    Triggers.by_category(:activity)
    |> Map.new(fn {trigger, _entry} ->
      {Triggers.preference_key(trigger), Notifications.preference_for(user, trigger)}
    end)
    |> to_form(as: :prefs)
  end

  defp group_triggers do
    %{
      transactional: sort_entries(Triggers.by_category(:transactional)),
      activity: sort_entries(Triggers.by_category(:activity))
    }
  end

  defp sort_entries(entries) do
    Enum.sort_by(entries, fn _atom_entry = {_atom, entry} -> entry.label end)
  end
end
