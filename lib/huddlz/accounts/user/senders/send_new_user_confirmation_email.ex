defmodule Huddlz.Accounts.User.Senders.SendNewUserConfirmationEmail do
  @moduledoc """
  Sends an email for a new user to confirm their email address.
  """

  use AshAuthentication.Sender
  use HuddlzWeb, :verified_routes

  alias Huddlz.Mailer
  alias Huddlz.Notifications.Footer
  alias Huddlz.Notifications.Layout

  @impl true
  def send(user, token, _) do
    user
    |> build(token)
    |> Mailer.deliver!()
  end

  @doc "The email, for tests and samples."
  def build(user, token) do
    confirm_url = url(~p"/confirm_new_user/#{token}")

    Layout.email(%{
      to: user.email,
      subject: "Confirm your email address",
      kicker: "Welcome to huddlz",
      title: "Confirm your email address",
      paragraphs: [
        "One quick step and your account is ready: confirm that this address is yours."
      ],
      action: {"Confirm my email", confirm_url},
      aside: "If you didn't create a huddlz account, you can ignore this email.",
      footer:
        Footer.account(
          "You're receiving this email because an account was created with this address."
        )
    })
  end
end
