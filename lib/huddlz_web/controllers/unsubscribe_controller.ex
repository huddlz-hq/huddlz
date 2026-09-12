defmodule HuddlzWeb.UnsubscribeController do
  @moduledoc """
  Unsubscribe confirmation flow reachable from the footer of any
  non-transactional notification email.

  The URL carries a `Phoenix.Token` payload of `{user_id, trigger}`.
  GET shows a confirmation page. POST sets
  `notification_preferences[trigger] = false` for that user, then redirects to
  `/profile/notifications` with a flash message.

  No authentication required — the token itself is the authorization.
  """

  use HuddlzWeb, :controller

  alias Huddlz.Accounts
  alias Huddlz.Accounts.User
  alias Huddlz.Admin.Impersonation
  alias Huddlz.Notifications
  alias Huddlz.Notifications.Triggers

  def show(conn, %{"token" => token}) do
    case verify(token) do
      {:ok, _user_id, _trigger, entry} ->
        conn
        |> assign(:body_class, "is-auth")
        |> render(:confirmation, token: token, entry: entry)

      :error ->
        invalid_link(conn)
    end
  end

  def update(conn, %{"token" => token}) do
    with {:ok, user_id, trigger, entry} <- verify(token),
         :ok <- check_recipient(conn.assigns[:current_user], user_id),
         {:ok, user} <- Accounts.get_user(user_id, authorize?: false),
         {:ok, _updated} <- opt_out(user, trigger, conn.assigns[:current_user]) do
      conn
      |> put_flash(
        :info,
        "Unsubscribed from \"#{entry.label}\". You can re-enable it any time below."
      )
      |> redirect(to: ~p"/profile/notifications")
    else
      :recipient_mismatch ->
        conn
        |> put_flash(
          :error,
          "This unsubscribe link belongs to someone else. Stop impersonation before using it."
        )
        |> redirect(to: ~p"/unsubscribe/#{token}")

      _ ->
        invalid_link(conn)
    end
  end

  defp check_recipient(
         %User{__metadata__: %{impersonation: %Impersonation{user_id: target_id}}},
         user_id
       )
       when target_id != user_id,
       do: :recipient_mismatch

  defp check_recipient(_user, _user_id), do: :ok

  defp verify(token) do
    with {:ok, {user_id, trigger}} <- Notifications.verify_unsubscribe_token(token),
         {:ok, entry} <- Triggers.fetch(trigger) do
      {:ok, user_id, trigger, entry}
    else
      _ -> :error
    end
  end

  defp invalid_link(conn) do
    conn
    |> put_flash(:error, "This unsubscribe link is invalid or has expired.")
    |> redirect(to: ~p"/")
  end

  defp opt_out(%User{} = user, trigger, actor) do
    key = Triggers.preference_key(trigger)

    if Map.get(user.notification_preferences || %{}, key) == false do
      {:ok, user}
    else
      Accounts.update_notification_preferences(
        user,
        %{preferences: %{key => false}},
        actor: actor,
        authorize?: false
      )
    end
  end
end
