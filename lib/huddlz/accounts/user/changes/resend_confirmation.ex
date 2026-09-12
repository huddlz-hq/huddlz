defmodule Huddlz.Accounts.User.Changes.ResendConfirmation do
  @moduledoc """
  Mints another confirmation link for the account's current address and
  sends the same email registration sent. Runs after the action inside its
  transaction: when the mailer refuses, the error rolls the new link back
  and the caller learns that nothing went out. Earlier links stay usable.
  """
  use Ash.Resource.Change

  alias Huddlz.Accounts.Confirmation
  alias Huddlz.Accounts.User.Errors.ConfirmationNotSent
  alias Huddlz.Accounts.User.Senders.SendNewUserConfirmationEmail
  alias Huddlz.Mailer

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, user ->
      with {:ok, token} <- Confirmation.mint(user),
           {:ok, _delivery} <-
             user |> SendNewUserConfirmationEmail.build(token) |> Mailer.deliver() do
        {:ok, user}
      else
        {:error, reason} -> {:error, ConfirmationNotSent.exception(reason: reason)}
        :error -> {:error, ConfirmationNotSent.exception(reason: :token)}
      end
    end)
  end
end
