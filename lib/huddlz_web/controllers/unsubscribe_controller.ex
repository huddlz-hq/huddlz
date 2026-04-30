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

  alias Huddlz.Accounts.User
  alias Huddlz.Notifications
  alias Huddlz.Notifications.Triggers

  def show(conn, %{"token" => token}) do
    case unsubscribe_context(token) do
      {:ok, %{entry: entry}} ->
        render_confirmation(conn, token, entry)

      :error ->
        invalid_link(conn)
    end
  end

  def update(conn, %{"token" => token}) do
    with {:ok, %{user: user, trigger: trigger, entry: entry}} <- unsubscribe_context(token),
         {:ok, _updated} <- opt_out(user, trigger) do
      conn
      |> put_flash(
        :info,
        "Unsubscribed from \"#{entry.label}\". You can re-enable it any time below."
      )
      |> redirect(to: ~p"/profile/notifications")
    else
      _ -> invalid_link(conn)
    end
  end

  defp unsubscribe_context(token) do
    with {:ok, {user_id, trigger}} <- Notifications.verify_unsubscribe_token(token),
         true <- known_trigger?(trigger),
         {:ok, user} <- Ash.get(User, user_id, authorize?: false) do
      {:ok, %{user: user, trigger: trigger, entry: Triggers.fetch!(trigger)}}
    else
      _ -> :error
    end
  end

  defp known_trigger?(trigger) when is_atom(trigger) do
    match?({:ok, _}, Triggers.fetch(trigger))
  end

  defp known_trigger?(_), do: false

  defp render_confirmation(conn, token, entry) do
    action = ~p"/unsubscribe/#{token}"
    csrf_token = Plug.CSRFProtection.get_csrf_token()

    html(conn, """
    <main class="mx-auto max-w-xl p-8">
      <h1>Confirm unsubscribe</h1>
      <p>Unsubscribe from "#{entry.label}"?</p>
      <form id="unsubscribe-confirmation-form" action="#{action}" method="post">
        <input type="hidden" name="_csrf_token" value="#{csrf_token}" />
        <button type="submit">Unsubscribe</button>
      </form>
    </main>
    """)
  end

  defp invalid_link(conn) do
    conn
    |> put_flash(:error, "This unsubscribe link is invalid or has expired.")
    |> redirect(to: ~p"/")
  end

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
