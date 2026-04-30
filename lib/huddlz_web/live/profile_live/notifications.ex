defmodule HuddlzWeb.ProfileLive.Notifications do
  @moduledoc """
  Settings page for the user's email notification preferences.

  Renders one checkbox per entry in `Huddlz.Notifications.Triggers`, grouped
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

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    {:ok,
     socket
     |> assign(:page_title, "Notification preferences")
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
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.header>
        Notification preferences
        <:subtitle>Choose which emails you want to receive from huddlz.</:subtitle>
      </.header>

      <.read_only_section
        title="Security"
        description="These messages always send. We can't disable them, but you'll always know about account-critical events."
        triggers={@triggers_by_category.transactional}
      />

      <form phx-submit="save" class="mt-10 space-y-10">
        <.category_section
          title="Activity"
          description="Updates about huddlz, RSVPs, and groups you're part of."
          triggers={@triggers_by_category.activity}
          user={@current_user}
        />

        <.category_section
          title="Digests"
          description="Optional summaries and re-engagement messages. Off by default."
          triggers={@triggers_by_category.digest}
          user={@current_user}
        />

        <div>
          <.button type="submit">Save preferences</.button>
        </div>
      </form>
    </Layouts.app>
    """
  end

  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :triggers, :list, required: true
  attr :user, :any, required: true

  defp category_section(assigns) do
    ~H"""
    <section class="border border-base-300 p-6">
      <h2 class="font-display text-2xl tracking-tight text-glow">{@title}</h2>
      <p class="text-base-content/70 mt-1">{@description}</p>

      <div class="mt-6 space-y-1">
        <.input
          :for={{trigger, entry} <- @triggers}
          type="checkbox"
          name={"prefs[#{trigger}]"}
          label={entry.label}
          checked={Notifications.preference_for(@user, trigger)}
        />
      </div>
    </section>
    """
  end

  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :triggers, :list, required: true

  defp read_only_section(assigns) do
    ~H"""
    <section class="border border-base-300 p-6">
      <h2 class="font-display text-2xl tracking-tight text-glow">{@title}</h2>
      <p class="text-base-content/70 mt-1">{@description}</p>

      <ul class="mt-6 space-y-2">
        <li
          :for={{_trigger, entry} <- @triggers}
          class="flex items-center gap-2 text-base-content"
        >
          <span class="mono-label text-primary/70">On</span>
          <span>{entry.label}</span>
        </li>
      </ul>
    </section>
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

  # `<.input type="checkbox">` submits "true" when checked and a paired hidden
  # input ensures "false" is submitted when unchecked. We iterate every editable
  # trigger here so the saved map stays exhaustive regardless of which keys the
  # client sends.
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
