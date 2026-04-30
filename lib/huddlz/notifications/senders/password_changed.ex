defmodule Huddlz.Notifications.Senders.PasswordChanged do
  @moduledoc """
  Sender for A3: password successfully changed.

  Sent to a user immediately after their password changes, as a security
  notice. Always sends (transactional) — preference toggles do not apply.
  """

  @behaviour Huddlz.Notifications.Sender

  use HuddlzWeb, :verified_routes
  import Swoosh.Email

  @impl true
  def build(user, _payload) do
    config = Application.get_env(:huddlz, :email, [])
    from_name = config[:from_name] || "huddlz support"
    from_address = config[:from_address] || "support@huddlz.com"
    reset_url = url(~p"/reset")

    new()
    |> from({from_name, from_address})
    |> to(to_string(user.email))
    |> subject("Your huddlz password was changed")
    |> html_body("""
    <p>Hi #{user.display_name},</p>

    <p>This is a security notice — your huddlz password was just changed.</p>

    <p>If this was you, no action is needed.</p>

    <p>If this <strong>wasn't</strong> you, reset your password immediately at
    <a href="#{reset_url}">#{reset_url}</a>
    and consider reviewing your account for any other unexpected changes.</p>
    """)
  end
end
