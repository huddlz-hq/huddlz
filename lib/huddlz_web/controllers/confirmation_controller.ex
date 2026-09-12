defmodule HuddlzWeb.ConfirmationController do
  @moduledoc """
  The two things the email confirmation reminder can do: send the
  confirmation email again, and hide the reminder for this browser session.
  Both answer with a flash and return to the page they were pressed on.
  The resend is the account action `resend_confirmation`; the words here
  say what it did or why it refused, never that the email arrived.
  """
  use HuddlzWeb, :controller

  alias Huddlz.Accounts
  alias Huddlz.Accounts.User
  alias Huddlz.Accounts.User.Errors.{ConfirmationNotSent, ResendLimited}

  def resend(conn, _params) do
    case conn.assigns[:current_user] do
      %User{} = user ->
        {kind, message} = user |> Accounts.resend_confirmation(actor: user) |> outcome(user)

        conn
        |> put_flash(kind, message)
        |> redirect(to: return_to(conn))

      _ ->
        redirect(conn, to: ~p"/sign-in")
    end
  end

  def hide(conn, _params) do
    conn
    |> put_session(:confirmation_reminder_hidden, true)
    |> redirect(to: return_to(conn))
  end

  defp outcome({:ok, _user}, user) do
    {:info,
     "Confirmation sent to #{user.email}. Give it a minute, and look in junk if it doesn't arrive."}
  end

  defp outcome({:error, error}, _user) do
    case find_error(error) do
      %ResendLimited{window: :minute, retry_after_ms: ms} ->
        {:error,
         "You requested a link less than a minute ago. Try again in #{max(1, div(ms + 999, 1000))} seconds."}

      %ResendLimited{window: :hour, retry_after_ms: ms} ->
        {:error,
         "You requested confirmation five times in the past hour. Try again in #{minutes(ms)}."}

      %ConfirmationNotSent{} ->
        {:error, "Couldn't send just now. Nothing went out. Try again in a minute."}

      _other ->
        {:error, "Couldn't send a confirmation email for this account."}
    end
  end

  defp minutes(ms) do
    case max(1, div(ms + 59_999, 60_000)) do
      1 -> "a minute"
      n -> "#{n} minutes"
    end
  end

  # Walk the Ash error tree for the first error of ours.
  defp find_error(%ResendLimited{} = error), do: error
  defp find_error(%ConfirmationNotSent{} = error), do: error

  defp find_error(%{errors: errors}) when is_list(errors),
    do: Enum.find_value(errors, &find_error/1)

  defp find_error(_error), do: nil

  # Back to the page the reminder was on, as long as it is one of ours.
  defp return_to(conn) do
    with [referer] <- get_req_header(conn, "referer"),
         %URI{path: path} when is_binary(path) <- URI.parse(referer),
         true <- String.starts_with?(path, "/") and not String.starts_with?(path, "//") do
      path
    else
      _ -> ~p"/agenda"
    end
  end
end
