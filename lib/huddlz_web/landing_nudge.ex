defmodule HuddlzWeb.LandingNudge do
  @moduledoc """
  POC for issue #670, variant F: rather than asking up front where someone
  wants to land after signing in, notice that their landing page keeps
  sending them elsewhere, and offer to change it.

  ## The detection here is a STAND-IN, not production logic

  `Huddlz.Accounts.User`'s `landing_departures` counter is bumped once per
  mount of an in-app page that is not the person's landing page. At
  `@departures_before_offer` the offer appears on their landing page.

  That is deliberately crude and should not ship as-is:

    * it counts any page that isn't the landing page, so idle browsing
      looks identical to "I came here for a huddl and the agenda was no
      help";
    * it never decays, so one curious afternoon marks the account forever;
    * it writes to the user record on page mounts, which is the wrong
      place for navigation signal.

  The POC question is whether the *offer* is welcome. Everything above is
  scaffolding to get the offer in front of a reviewer, and a production
  version would replace it wholesale. See the PR for #670.

  The nudge itself is the part meant to be judged: three actions, one of
  them permanent ("Don't ask again" persists to the user record), one of
  them free ("Not now" leaves it for next time).
  """

  use HuddlzWeb, :html

  alias Huddlz.Accounts.LandingPreference
  alias Huddlz.Accounts.User
  alias Phoenix.LiveView

  # Stand-in threshold. Low enough to feel in a POC, not a researched number.
  @departures_before_offer 3

  # Landing pages worth offering. The agenda is excluded as a destination
  # when it is already where the person lands.
  @offerable [:groups, :discover]

  @doc "How many departures the stand-in detector waits for."
  def departures_before_offer, do: @departures_before_offer

  @doc """
  Attach to a LiveView that renders the app chrome. Counts departures from
  the person's landing page and answers the nudge's three actions.
  """
  def attach(%{assigns: %{current_user: %User{}}} = socket) do
    socket
    |> LiveView.attach_hook(:landing_nudge_params, :handle_params, &note_arrival/3)
    |> LiveView.attach_hook(:landing_nudge_events, :handle_event, &handle_action/3)
  end

  def attach(socket), do: socket

  @doc """
  True when the person should be offered a different landing page: they are
  on their landing page, they have left it enough times, and they have not
  asked to be left alone.
  """
  def offer?(%User{landing_nudge_declined: true}, _path), do: false

  def offer?(%User{} = user, path) do
    user.landing_departures >= @departures_before_offer and landing?(user, path)
  end

  def offer?(_user, _path), do: false

  @doc "The landing pages this person could be offered instead of their current one."
  def alternatives(%User{landing_preference: current}),
    do: Enum.reject(@offerable, &(&1 == current))

  def alternatives(_user), do: @offerable

  # --- hooks ---------------------------------------------------------------

  defp note_arrival(_params, uri, socket) do
    user = socket.assigns[:current_user]
    path = path_of(uri)

    socket =
      if count_departure?(user, path) do
        bump(socket, user)
      else
        socket
      end

    {:cont, assign(socket, :landing_nudge_path, path)}
  end

  defp count_departure?(%User{landing_nudge_declined: true}, _path), do: false

  defp count_departure?(%User{} = user, path) do
    not landing?(user, path) and in_app?(path) and
      user.landing_departures < @departures_before_offer
  end

  defp count_departure?(_user, _path), do: false

  defp bump(socket, user) do
    user
    |> Ash.Changeset.for_update(:note_landing_departure, %{}, actor: user)
    |> Ash.update()
    |> case do
      {:ok, updated} -> assign(socket, :current_user, updated)
      {:error, _} -> socket
    end
  end

  defp handle_action("landing_nudge_change", %{"landing" => landing}, socket) do
    user = socket.assigns.current_user

    user
    |> Ash.Changeset.for_update(
      :update_landing_preference,
      %{landing_preference: landing},
      actor: user
    )
    |> Ash.update()
    |> case do
      {:ok, updated} ->
        {:halt,
         socket
         |> assign(:current_user, updated)
         |> assign(:landing_nudge_hidden?, true)
         |> LiveView.put_flash(
           :info,
           "You'll land on #{LandingPreference.label(updated.landing_preference)} after signing in"
         )}

      {:error, _} ->
        {:halt, LiveView.put_flash(socket, :error, "Could not change where you land")}
    end
  end

  defp handle_action("landing_nudge_dismiss", _params, socket) do
    {:halt, assign(socket, :landing_nudge_hidden?, true)}
  end

  defp handle_action("landing_nudge_decline", _params, socket) do
    user = socket.assigns.current_user

    user
    |> Ash.Changeset.for_update(:dismiss_landing_nudge, %{}, actor: user)
    |> Ash.update()
    |> case do
      {:ok, updated} ->
        {:halt,
         socket
         |> assign(:current_user, updated)
         |> assign(:landing_nudge_hidden?, true)}

      {:error, _} ->
        {:halt, LiveView.put_flash(socket, :error, "Could not save that")}
    end
  end

  defp handle_action(_event, _params, socket), do: {:cont, socket}

  # --- paths ---------------------------------------------------------------

  defp landing?(%User{landing_preference: preference}, path),
    do: path == path_of(LandingPreference.path(preference))

  # Only first-class destinations count as "somewhere else". A huddl page or
  # a settings page is not evidence that the landing page is wrong.
  defp in_app?(path), do: path in ["/discover", "/agenda", "/groups", "/calendar/week"]

  defp path_of(uri) when is_binary(uri) do
    case URI.parse(uri) do
      %URI{path: nil} -> "/"
      %URI{path: p} -> p
    end
  end

  defp path_of(_), do: "/"

  # --- UI ------------------------------------------------------------------

  attr :user, :map, required: true
  attr :path, :string, required: true
  attr :hidden, :boolean, default: false

  @doc """
  The offer itself: the part of this POC actually up for judgement.
  """
  def nudge(assigns) do
    ~H"""
    <aside
      :if={!@hidden and offer?(@user, @path)}
      id="landing-nudge"
      class="landing-nudge"
      role="region"
      aria-label="Where you land after signing in"
    >
      <span class="landing-nudge-mark" aria-hidden="true">
        <.icon name="hero-sparkles" class="size-5" />
      </span>

      <div class="landing-nudge-body">
        <p class="landing-nudge-title">Change where you land after login?</p>
        <p class="landing-nudge-copy">
          You keep heading somewhere else after signing in. huddlz can open there instead.
        </p>
      </div>

      <div class="landing-nudge-actions">
        <button
          :for={landing <- alternatives(@user)}
          type="button"
          class="landing-nudge-primary"
          phx-click="landing_nudge_change"
          phx-value-landing={landing}
        >
          <span class="landing-nudge-primary-label">
            Land on {LandingPreference.label(landing)}
          </span>
          <span class="landing-nudge-primary-hint">{LandingPreference.hint(landing)}</span>
        </button>
        <button type="button" class="landing-nudge-quiet" phx-click="landing_nudge_dismiss">
          Not now
        </button>
        <button type="button" class="landing-nudge-quiet" phx-click="landing_nudge_decline">
          Don't ask again
        </button>
      </div>
    </aside>
    """
  end
end
