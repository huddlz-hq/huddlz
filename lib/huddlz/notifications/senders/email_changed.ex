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

  use HuddlzWeb, :verified_routes
  import Swoosh.Email

  alias Huddlz.Mailer
  alias Huddlz.Notifications.Senders.HtmlEscape

  @subject "Your huddlz email address was changed"

  @impl true
  def build(user, %{"audience" => "old"} = payload) do
    old_email = payload["old_email"]
    new_email = to_string(user.email)
    safe_name = HtmlEscape.escape(user.display_name)
    safe_new_email = HtmlEscape.escape(new_email)

    new()
    |> from(Mailer.from())
    |> to(old_email)
    |> subject(@subject)
    |> html_body(html_old(safe_name, safe_new_email))
    |> text_body(text_old(user.display_name, new_email))
  end

  def build(user, %{"audience" => "new"} = payload) do
    old_email = payload["old_email"]
    new_email = to_string(user.email)
    safe_name = HtmlEscape.escape(user.display_name)
    safe_old_email = HtmlEscape.escape(old_email)

    new()
    |> from(Mailer.from())
    |> to(new_email)
    |> subject(@subject)
    |> html_body(html_new(safe_name, safe_old_email))
    |> text_body(text_new(user.display_name, old_email))
  end

  def build(_user, payload) do
    raise ArgumentError,
          "EmailChanged sender received an unknown audience in payload: #{inspect(payload)}. " <>
            "Expected `audience: \"old\"` or `audience: \"new\"`."
  end

  defp html_old(safe_name, safe_new_email) do
    """
    <p>Hi #{safe_name},</p>

    <p>This is a security notice — the email address on your huddlz account was
    just changed to <strong>#{safe_new_email}</strong>.</p>

    <p>If this was you, no action is needed. Future emails from huddlz will
    go to your new address.</p>

    <p>If this <strong>wasn't</strong> you, contact support right away so we
    can restore access. Resetting your password won't help here — the reset
    email would go to the new address, not this one.</p>
    """
  end

  defp text_old(name, new_email) do
    """
    Hi #{name},

    This is a security notice — the email address on your huddlz account was
    just changed to #{new_email}.

    If this was you, no action is needed. Future emails from huddlz will go to
    your new address.

    If this wasn't you, contact support right away so we can restore access.
    Resetting your password won't help here — the reset email would go to the
    new address, not this one.
    """
  end

  defp html_new(safe_name, safe_old_email) do
    """
    <p>Hi #{safe_name},</p>

    <p>This email address is now associated with your huddlz account.
    The previous address on file was <strong>#{safe_old_email}</strong>.</p>

    <p>If you didn't make this change, contact support right away — someone
    else may have access to your account.</p>
    """
  end

  defp text_new(name, old_email) do
    """
    Hi #{name},

    This email address is now associated with your huddlz account. The
    previous address on file was #{old_email}.

    If you didn't make this change, contact support right away — someone
    else may have access to your account.
    """
  end
end
