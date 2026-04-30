defmodule Huddlz.Notifications.Senders.AccountRoleChanged do
  @moduledoc """
  Sender for A5: an admin changed this user's account role.

  Activity-category email — respects the user's notification preferences and
  includes an unsubscribe link in the footer.
  """

  @behaviour Huddlz.Notifications.Sender

  use HuddlzWeb, :verified_routes
  import Swoosh.Email

  alias Huddlz.Mailer
  alias Huddlz.Notifications

  @impl true
  def build(user, payload) do
    new_role = payload["new_role"] || to_string(user.role)
    previous_role = payload["previous_role"]

    safe_name = Phoenix.HTML.html_escape(user.display_name) |> Phoenix.HTML.safe_to_string()
    safe_new_role = Phoenix.HTML.html_escape(new_role) |> Phoenix.HTML.safe_to_string()

    safe_previous_role =
      if previous_role do
        Phoenix.HTML.html_escape(previous_role) |> Phoenix.HTML.safe_to_string()
      end

    settings_url = url(~p"/profile/notifications")

    unsubscribe_url =
      url(~p"/unsubscribe/#{Notifications.unsubscribe_token(user, :account_role_changed)}")

    new()
    |> from(Mailer.from())
    |> to(to_string(user.email))
    |> subject("Your huddlz account role was updated")
    |> html_body(
      html_body(safe_name, safe_new_role, safe_previous_role, settings_url, unsubscribe_url)
    )
    |> text_body(
      text_body(user.display_name, new_role, previous_role, settings_url, unsubscribe_url)
    )
  end

  defp html_body(safe_name, safe_new_role, safe_previous_role, settings_url, unsubscribe_url) do
    change_phrase =
      if safe_previous_role do
        "from <strong>#{safe_previous_role}</strong> to <strong>#{safe_new_role}</strong>"
      else
        "to <strong>#{safe_new_role}</strong>"
      end

    """
    <p>Hi #{safe_name},</p>

    <p>An administrator just updated your huddlz account role #{change_phrase}.</p>

    <p>If this looks wrong, reply to this email and we'll sort it out.</p>

    <hr/>
    <p style="font-size: 0.85em; color: #666;">
      You're receiving this because role-change notifications are on.
      <a href="#{settings_url}">Manage notification settings</a> ·
      <a href="#{unsubscribe_url}">Unsubscribe from these</a>
    </p>
    """
  end

  defp text_body(name, new_role, previous_role, settings_url, unsubscribe_url) do
    change_phrase =
      if previous_role do
        "from #{previous_role} to #{new_role}"
      else
        "to #{new_role}"
      end

    """
    Hi #{name},

    An administrator just updated your huddlz account role #{change_phrase}.

    If this looks wrong, reply to this email and we'll sort it out.

    --
    You're receiving this because role-change notifications are on.
    Manage notification settings: #{settings_url}
    Unsubscribe from these: #{unsubscribe_url}
    """
  end
end
