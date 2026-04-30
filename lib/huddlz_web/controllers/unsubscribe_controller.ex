defmodule HuddlzWeb.UnsubscribeController do
  @moduledoc """
  One-click unsubscribe endpoint reachable from the footer of any
  non-transactional notification email.

  The URL carries a `Phoenix.Token` payload of `{user_id, trigger}`.
  Hitting it sets `notification_preferences[trigger] = false` for that user,
  then redirects to `/profile/notifications` with a flash message.

  No authentication required — the token itself is the authorization.
  """

  use HuddlzWeb, :controller

  alias Huddlz.Accounts.User
  alias Huddlz.Notifications
  alias Huddlz.Notifications.Triggers

  def show(conn, %{"token" => token}) do
    with {:ok, {user_id, trigger}} <- Notifications.verify_unsubscribe_token(token),
         true <- known_trigger?(trigger),
         {:ok, user} <- Ash.get(User, user_id, authorize?: false),
         {:ok, _updated} <- opt_out(user, trigger) do
      label = Triggers.fetch!(trigger).label

      conn
      |> put_flash(:info, "Unsubscribed from \"#{label}\". You can re-enable it any time below.")
      |> redirect(to: ~p"/profile/notifications")
    else
      _ ->
        conn
        |> put_flash(:error, "This unsubscribe link is invalid or has expired.")
        |> redirect(to: ~p"/")
    end
  end

  defp known_trigger?(trigger) when is_atom(trigger) do
    match?({:ok, _}, Triggers.fetch(trigger))
  end

  defp known_trigger?(_), do: false

  defp opt_out(%User{} = user, trigger) do
    key = Triggers.preference_key(trigger)

    user
    |> Ash.Changeset.for_update(
      :update_notification_preferences,
      %{preferences: %{key => false}},
      authorize?: false
    )
    |> Ash.update()
  end
end
