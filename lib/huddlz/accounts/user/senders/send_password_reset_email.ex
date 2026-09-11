defmodule Huddlz.Accounts.User.Senders.SendPasswordResetEmail do
  @moduledoc """
  Sends a password reset email.
  """

  use AshAuthentication.Sender
  use HuddlzWeb, :verified_routes

  alias Huddlz.Mailer
  alias Huddlz.Notifications.Footer
  alias Huddlz.Notifications.Layout

  @impl true
  def send(user, token, _) do
    with {:ok, _receipt} <- user |> build(token) |> Mailer.deliver() do
      :ok
    end
  end

  @doc "The email, for tests and samples."
  def build(user, token) do
    reset_url = url(~p"/reset/#{token}")

    Layout.email(%{
      to: user.email,
      subject: "Reset your password",
      kicker: "Your account",
      title: "Reset your password",
      paragraphs: [
        [
          "Someone asked to reset the password for the huddlz account at ",
          {:strong, to_string(user.email)},
          ". If that was you, choose a new password with the button below."
        ]
      ],
      action: {"Reset password", reset_url},
      aside:
        "If you didn't ask for this, you can ignore this email; your password stays as it is.",
      footer:
        Footer.account(
          "You're receiving this email because a password reset was requested for this address."
        )
    })
  end
end
