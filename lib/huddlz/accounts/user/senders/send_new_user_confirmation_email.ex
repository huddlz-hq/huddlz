defmodule Huddlz.Accounts.User.Senders.SendNewUserConfirmationEmail do
  @moduledoc """
  Sends an email for a new user to confirm their email address.
  """

  use AshAuthentication.Sender
  use HuddlzWeb, :verified_routes

  import Swoosh.Email

  alias Huddlz.Mailer

  @impl true
  def send(user, token, _) do
    config = Application.get_env(:huddlz, :email)
    from_name = config[:from_name] || "huddlz support"
    from_address = config[:from_address] || "support@huddlz.com"

    new()
    |> from({from_name, from_address})
    |> to(to_string(user.email))
    |> subject("Confirm your email address")
    |> html_body(body(token: token))
    |> Mailer.deliver!()
  end

  defp body(params) do
    url = url(~p"/confirm_new_user/#{params[:token]}")

    """
    <p>Click this link to confirm your email:</p>
    <p><a href="#{url}">#{url}</a></p>
    """
  end
end
