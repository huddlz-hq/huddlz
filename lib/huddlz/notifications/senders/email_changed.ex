defmodule Huddlz.Notifications.Senders.EmailChanged do
  @moduledoc """
  Sender for A4: a user's email address was changed.

  Two audiences, both transactional:

    * `audience: "old"` — the previous address. Security notice that
      directs the user to contact support if the change was unauthorized.
      No `/reset` link: by this point the recovery channel (the reset
      email) goes to the *new* address, which a hijacker would control.
    * `audience: "new"` — the new address. Confirmation that this address
      is now associated with the account.

  The trigger is `:email_changed`. After_action enqueues the worker twice,
  once per audience. Both jobs share the trigger and pass `payload[
  "old_email"]` so each side has the full picture.
  """

  @behaviour Huddlz.Notifications.Sender

  alias Huddlz.Notifications.Footer
  alias Huddlz.Notifications.Layout

  @subject "Your huddlz email address was changed"

  @impl true
  def build(user, %{"audience" => "old"} = payload) do
    # Recipient header injection is prevented by the `User.email` regex constraint
    # rejecting whitespace (CR/LF). Swoosh does not sanitize recipient strings.
    Layout.email(%{
      to: payload["old_email"],
      subject: @subject,
      kicker: "Security notice",
      title: "Your email address was changed",
      paragraphs: [
        [
          "Hi #{user.display_name}, this is a security notice: the email address on your huddlz account was just changed to ",
          {:strong, to_string(user.email)},
          "."
        ],
        "If this was you, no action is needed. Future emails from huddlz will go to your new address.",
        [
          "If this ",
          {:strong, "wasn't"},
          " you, contact support right away so we can restore access. Resetting your password won't help here: the reset email would go to the new address, not this one."
        ]
      ],
      footer: Footer.account()
    })
  end

  def build(user, %{"audience" => "new"} = payload) do
    Layout.email(%{
      to: user.email,
      subject: @subject,
      kicker: "Your account",
      title: "This is now your huddlz email address",
      paragraphs: [
        [
          "Hi #{user.display_name}, this email address is now associated with your huddlz account. The previous address on file was ",
          {:strong, payload["old_email"]},
          "."
        ],
        "If you didn't make this change, contact support right away: someone else may have access to your account."
      ],
      footer: Footer.account()
    })
  end

  def build(_user, payload) do
    raise ArgumentError,
          "EmailChanged sender received an unknown audience in payload: #{inspect(payload)}. " <>
            "Expected `audience: \"old\"` or `audience: \"new\"`."
  end
end
