defmodule HuddlzWeb.LiveUserAuth do
  @moduledoc """
  Helpers for authenticating users in LiveViews.
  """

  import Phoenix.Component
  use HuddlzWeb, :verified_routes

  alias AshAuthentication.Phoenix.LiveSession
  alias Huddlz.Accounts.User

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

  # Gate a LiveView on admin-only access. The "is this user an admin?" rule
  # lives on the User resource (`User.admin?/1` + the `:is_admin` calculation),
  # so this hook stays in sync with the policy bypass that uses the same role
  # check on every Ash action.
  def on_mount(:admin_required, _params, _session, socket) do
    if User.admin?(socket.assigns[:current_user]) do
      {:cont, socket}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}
    end
  end

  def on_mount(:load_user_details, _params, _session, socket) do
    {:cont, maybe_load_user_details(socket)}
  end

  # Pair with `<Layouts.app>` in the LiveView template. Assigns
  # `is-signed-out` when there's no actor so the body switches from the
  # sidebar grid to the single-column shell rendered by `Layouts.app`
  # in chromeless mode.
  #
  # Also loads the user details the sidebar reads (profile picture URL, home
  # location) plus the groups the user organizes, which appear as `sb-org-row`
  # entries in the sidebar.
  def on_mount(:app, _params, _session, socket) do
    body_class = if socket.assigns[:current_user], do: "", else: "is-signed-out"

    {:cont,
     socket
     |> maybe_load_user_details()
     |> assign(:body_class, body_class)
     |> assign_new(:sidebar_owned_groups, fn -> load_sidebar_owned_groups(socket) end)}
  end

  defp maybe_load_user_details(%{assigns: %{current_user: user}} = socket)
       when not is_nil(user) do
    case Ash.load(
           user,
           [
             :current_profile_picture_url,
             :home_location,
             :home_latitude,
             :home_longitude,
             :is_admin
           ],
           actor: user
         ) do
      {:ok, loaded_user} -> assign(socket, :current_user, loaded_user)
      _ -> socket
    end
  end

  defp maybe_load_user_details(socket), do: socket

  defp load_sidebar_owned_groups(%{assigns: %{current_user: user}}) when not is_nil(user) do
    Huddlz.Communities.get_organizable_groups!(actor: user, query: [sort: [name: :asc]])
  end

  defp load_sidebar_owned_groups(_socket), do: []
end
