defmodule HuddlzWeb.LiveUserAuth do
  @moduledoc """
  Helpers for authenticating users in LiveViews.
  """

  import Phoenix.Component
  use HuddlzWeb, :verified_routes

  alias AshAuthentication.Phoenix.LiveSession
  alias Huddlz.Accounts.User
  alias Huddlz.Communities.MembershipEvents
  alias Huddlz.Notifications

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

  def on_mount(:redirect_to_calendar_if_authenticated, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/calendar")}
    else
      {:cont, assign(socket, :current_user, nil)}
    end
  end

  # Gate a LiveView on admin-only access. The "is this user an admin?" rule
  # lives on the User resource (`User.admin?/1` + the `:is_admin` calculation),
  # so this hook stays in sync with the policy bypass that uses the same role
  # check on every Ash action.
  def on_mount(:admin_required, _params, _session, socket) do
    case socket.assigns[:current_user] do
      nil ->
        {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}

      user ->
        authorize_admin(user, socket)
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

    socket =
      socket
      |> maybe_load_user_details()
      |> assign(:body_class, body_class)
      |> assign_new(:sidebar_owned_groups, fn -> load_sidebar_owned_groups(socket) end)
      |> assign_new(:unread_notification_count, fn -> load_unread_notification_count(socket) end)
      |> subscribe_to_organizer_access_changes()
      |> maybe_subscribe_to_unread_count()

    {:cont, socket}
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

  defp authorize_admin(user, socket) do
    if User.admin?(user) do
      {:cont, socket}
    else
      {:halt,
       socket
       |> Phoenix.LiveView.put_flash(:error, "You don't have access to the admin area.")
       |> Phoenix.LiveView.redirect(to: ~p"/calendar")}
    end
  end

  defp load_sidebar_owned_groups(%{assigns: %{current_user: user}}) when not is_nil(user) do
    Huddlz.Communities.get_organizable_groups!(
      actor: user,
      load: [:member_count],
      query: [sort: [name: :asc]]
    )
  end

  defp load_sidebar_owned_groups(_socket), do: []

  defp load_unread_notification_count(%{assigns: %{current_user: %User{} = user}}) do
    case Notifications.unread_count(user) do
      {:ok, count} -> count
      {:error, _reason} -> 0
    end
  end

  defp load_unread_notification_count(_socket), do: 0

  defp maybe_subscribe_to_unread_count(
         %{assigns: %{current_user: %User{id: user_id} = user}} = socket
       ) do
    if Phoenix.LiveView.connected?(socket) do
      :ok = Notifications.subscribe_to_unread_count(user)

      Phoenix.LiveView.attach_hook(
        socket,
        :unread_notification_count,
        :handle_info,
        fn
          {:notification_unread_count_changed, ^user_id}, socket ->
            {:halt,
             assign(socket, :unread_notification_count, load_unread_notification_count(socket))}

          _message, socket ->
            {:cont, socket}
        end
      )
    else
      socket
    end
  end

  defp maybe_subscribe_to_unread_count(socket), do: socket

  defp subscribe_to_organizer_access_changes(%{assigns: %{current_user: %{id: user_id}}} = socket) do
    if Phoenix.LiveView.connected?(socket) do
      :ok = MembershipEvents.subscribe_to_user(user_id)

      Phoenix.LiveView.attach_hook(
        socket,
        :refresh_organizer_access,
        :handle_info,
        &refresh_organizer_access/2
      )
    else
      socket
    end
  end

  defp subscribe_to_organizer_access_changes(socket), do: socket

  defp refresh_organizer_access(
         {:organizer_access_changed, user_id},
         %{assigns: %{current_user: %{id: user_id}}} = socket
       ) do
    groups = load_sidebar_owned_groups(socket)

    socket =
      socket
      |> assign(:sidebar_owned_groups, groups)
      |> maybe_assign_picker_groups(groups)

    {:halt, socket}
  end

  defp refresh_organizer_access(_message, socket), do: {:cont, socket}

  defp maybe_assign_picker_groups(%{assigns: %{owned_groups: _}} = socket, groups) do
    assign(socket, :owned_groups, groups)
  end

  defp maybe_assign_picker_groups(socket, _groups), do: socket
end
