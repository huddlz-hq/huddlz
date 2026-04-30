defmodule Huddlz.Notifications.Footer do
  @moduledoc """
  Shared unsubscribe / settings footer markup for Activity emails.

  Builds a per-trigger unsubscribe URL from `Notifications.unsubscribe_token/2`
  and a link to the notification settings page. Returned as `{html, text}`
  so senders can splice both bodies.
  """

  use HuddlzWeb, :verified_routes

  alias Huddlz.Accounts.User
  alias Huddlz.Notifications

  @doc """
  Returns `{html_footer, text_footer}` for the given user + trigger.
  """
  @spec build(User.t(), atom()) :: {String.t(), String.t()}
  def build(%User{} = user, trigger) when is_atom(trigger) do
    token = Notifications.unsubscribe_token(user, trigger)
    unsub_url = url(~p"/unsubscribe/#{token}")
    settings_url = url(~p"/profile/notifications")

    html = """
    <hr/>
    <p style="font-size: 0.85em; color: #666;">
      You're receiving this email because of your huddlz notification settings.
      <a href="#{unsub_url}">Unsubscribe from this kind of email</a>
      or <a href="#{settings_url}">manage all your preferences</a>.
    </p>
    """

    text = """

    ---
    You're receiving this email because of your huddlz notification settings.
    Unsubscribe from this kind of email: #{unsub_url}
    Manage all your preferences: #{settings_url}
    """

    {html, text}
  end
end
