defmodule HuddlzWeb.WelcomeLive do
  @moduledoc """
  POC variant E — the question huddlz asks once, right after signing in, when
  it has nothing better to go on: did you come for your own huddlz, or to find
  a new one?

  The post-sign-in destination is only guessable when the person arrived with
  an explicit return destination (see `HuddlzWeb.AuthReturnTo`). Without one,
  `HuddlzWeb.AuthController` sends people here instead of guessing.

  Asked once. The answer is stored on the person's `landing_choice`, so this
  page never appears again — someone who already answered is sent straight to
  the landing they picked. "Not sure yet" leaves the answer unrecorded and
  lands them on the agenda, so the question is still open next time and nobody
  is cornered into answering it.

  Every choice is logged so the distribution of answers is observable; that
  distribution is the deliverable this variant exists to produce.
  """

  use HuddlzWeb, :live_view

  require Logger


  on_mount {HuddlzWeb.LiveUserAuth, :live_user_required}
  on_mount {HuddlzWeb.LiveUserAuth, :app}

  @question "What brings you to huddlz today?"

  @impl true
  def mount(_params, _session, socket) do
    case socket.assigns.current_user do
      %{landing_choice: choice} when choice in [:my_huddlz, :find_a_huddl] ->
        {:ok, redirect(socket, to: landing_path(choice))}

      _ ->
        {:ok,
         socket
         |> assign(:page_title, "Welcome to huddlz")
         |> assign(:question, @question)}
    end
  end

  @impl true
  def handle_event("choose", %{"choice" => raw}, socket) do
    choice = parse_choice(raw)
    user = socket.assigns.current_user

    log_choice(choice, user)

    case record_choice(user, choice) do
      {:ok, _user} ->
        {:noreply, redirect(socket, to: landing_path(choice))}

      {:error, _error} ->
        # Remembering the answer is a convenience, not the point. If it fails,
        # still honor what the person just asked for.
        {:noreply, redirect(socket, to: landing_path(choice))}
    end
  end

  defp parse_choice("find_a_huddl"), do: :find_a_huddl
  defp parse_choice(_other), do: :my_huddlz

  defp record_choice(user, choice) do
    user
    |> Ash.Changeset.for_update(:update_landing_choice, %{landing_choice: choice}, actor: user)
    |> Ash.update()
  end

  # The only telemetry this POC needs: one line per answer, greppable, so the
  # distribution can be counted without any analytics plumbing.
  defp log_choice(choice, user) do
    Logger.info("post_sign_in_intent choice=#{choice} user_id=#{user.id}")
  end

  defp landing_path(:find_a_huddl), do: ~p"/discover"
  defp landing_path(_my_huddlz), do: ~p"/agenda"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      unread_notification_count={@unread_notification_count}
      sidebar_owned_groups={@sidebar_owned_groups}
    >
      <div class="intent-page">
        <div class="intent-card">
          <p class="intent-eyebrow">Welcome back, {display_name(@current_user)}</p>
          <h1 class="intent-question">{@question}</h1>
          <p class="intent-lede">
            Pick one and huddlz will start you there from now on. You can change it any time
            from the sidebar.
          </p>

          <div class="intent-choices">
            <button
              type="button"
              phx-click="choose"
              phx-value-choice="my_huddlz"
              class="intent-choice"
            >
              <span class="intent-choice-icon">
                <.icon name="hero-calendar-days" class="size-6" />
              </span>
              <span class="intent-choice-text">
                <span class="intent-choice-title">See my huddlz</span>
                <span class="intent-choice-desc">
                  Your agenda — what you've said yes to, and what your groups have scheduled.
                </span>
              </span>
              <span class="intent-choice-arrow" aria-hidden="true">
                <.icon name="hero-arrow-right" class="size-5" />
              </span>
            </button>

            <button
              type="button"
              phx-click="choose"
              phx-value-choice="find_a_huddl"
              class="intent-choice"
            >
              <span class="intent-choice-icon">
                <.icon name="hero-magnifying-glass" class="size-6" />
              </span>
              <span class="intent-choice-text">
                <span class="intent-choice-title">Find a new one</span>
                <span class="intent-choice-desc">
                  Browse huddlz near you, including ones from groups you haven't joined.
                </span>
              </span>
              <span class="intent-choice-arrow" aria-hidden="true">
                <.icon name="hero-arrow-right" class="size-5" />
              </span>
            </button>
          </div>

          <div class="intent-escape">
            <.link navigate={~p"/agenda"} class="intent-skip">
              Not sure yet
            </.link>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp display_name(%{display_name: name}) when is_binary(name) and name != "" do
    name |> String.split(" ") |> List.first()
  end

  defp display_name(_user), do: "there"
end
