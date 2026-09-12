defmodule Huddlz.Accounts.User.Errors.ConfirmationNotSent do
  @moduledoc "The confirmation email could not be handed to the mailer; nothing went out."
  use Splode.Error, fields: [:reason], class: :invalid

  def message(_), do: "the confirmation email could not be sent"

  defimpl AshGraphql.Error do
    def to_error(error) do
      message = Exception.message(error)
      %{message: message, short_message: message, vars: %{}, code: "not_sent", fields: []}
    end
  end
end
