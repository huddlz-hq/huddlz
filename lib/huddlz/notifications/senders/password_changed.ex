defmodule Huddlz.Notifications.Senders.PasswordChanged do
  @moduledoc """
  Sender for A1: the recipient's password was changed. Transactional
  security notice.

  The recipient's address is the current account email, so the
  password-reset channel is intact and the notice may point at `/reset`.
  See `docs/notifications.md` § Recovery advice in security notices.
  """

  @behaviour Huddlz.Notifications.Sender

  use HuddlzWeb, :verified_routes

  alias Huddlz.Notifications.Footer
  alias Huddlz.Notifications.Layout

  @impl true
  def build(user, _payload) do
    reset_url = url(~p"/reset")

    Layout.email(%{
      to: user.email,
      subject: "Your huddlz password was changed",
      kicker: "Security notice",
      title: "Your password was changed",
      paragraphs: [
        "Hi #{user.display_name}, this is a security notice: your huddlz password was just changed.",
        "If this was you, no action is needed.",
        [
          "If this ",
          {:strong, "wasn't"},
          " you, reset your password immediately at ",
          {:link, reset_url, reset_url},
          " and consider reviewing your account for any other unexpected changes."
        ]
      ],
      footer: Footer.account()
    })
  end
end
