defmodule Huddlz.Accounts.User.Errors.ResendLimited do
  @moduledoc """
  The account asked for its confirmation email again too soon: once a
  minute and five an hour is the ceiling. Carries which window refused and
  how long until it opens again, so the answer can say when to try.
  """
  use Splode.Error, fields: [:window, :limit, :retry_after_ms], class: :forbidden

  def message(%{window: :minute}), do: "a confirmation email was sent less than a minute ago"
  def message(%{window: :hour}), do: "five confirmation emails were sent in the past hour"

  defimpl Plug.Exception do
    def actions(_), do: []
    def status(_), do: 429
  end

  defimpl AshGraphql.Error do
    def to_error(error) do
      message = Exception.message(error)

      %{
        message: message,
        short_message: message,
        vars: %{},
        code: "too_many_requests",
        fields: []
      }
    end
  end
end
