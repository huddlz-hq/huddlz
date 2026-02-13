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
