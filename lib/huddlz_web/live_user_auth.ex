defmodule HuddlzWeb.LiveUserAuth do
  @moduledoc """
  Helpers for authenticating users in LiveViews.
  """

  import Phoenix.Component
  use HuddlzWeb, :verified_routes

  alias AshAuthentication.Phoenix.LiveSession

  # This is used for nested liveviews to fetch the current user.
  # To use, place the following at the top of that liveview:
  # on_mount {HuddlzWeb.LiveUserAuth, :current_user}
  def on_mount(:current_user, _params, session, socket) do
    socket = LiveSession.assign_new_resources(socket, session)
    {:cont, maybe_load_user_details(socket)}
  end

  def on_mount(:live_user_optional, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:cont, socket}
    else
      {:cont, assign(socket, :current_user, nil)}
    end
  end

  def on_mount(:live_user_required, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:cont, socket}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}
    end
  end

  def on_mount(:live_no_user, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}
    else
      {:cont, assign(socket, :current_user, nil)}
    end
  end

  def on_mount(:redirect_to_me_if_authenticated, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/my-huddlz")}
    else
      {:cont, assign(socket, :current_user, nil)}
    end
  end

  def on_mount([role_required: role_required], _params, _session, socket) do
    current_user = socket.assigns[:current_user]

    if current_user && current_user.role == role_required do
      {:cont, socket}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}
    end
  end

  def on_mount(:load_user_details, _params, _session, socket) do
    {:cont, maybe_load_user_details(socket)}
  end

  # Flips the body class to `"v3"` so v3-scoped styles in app.css take effect.
  # Pair with `<Layouts.v3_app>` in the LiveView template. Adds `is-signed-out`
  # when there's no actor, so the body switches from the sidebar grid to the
  # single-column shell rendered by `Layouts.v3_app` in chromeless mode.
  #
  # Also loads the user details the sidebar reads (profile picture URL, home
  # location) so the bottom-of-sidebar avatar can render an uploaded image
  # rather than a blank gradient square.
  def on_mount(:v3_app, _params, _session, socket) do
    body_class =
      if socket.assigns[:current_user], do: "v3", else: "v3 is-signed-out"

    {:cont,
     socket
     |> maybe_load_user_details()
     |> assign(:body_class, body_class)}
  end

  defp maybe_load_user_details(%{assigns: %{current_user: user}} = socket)
       when not is_nil(user) do
    case Ash.load(
           user,
           [:current_profile_picture_url, :home_location, :home_latitude, :home_longitude],
           actor: user
         ) do
      {:ok, loaded_user} -> assign(socket, :current_user, loaded_user)
      _ -> socket
    end
  end

  defp maybe_load_user_details(socket), do: socket
end
