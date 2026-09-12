defmodule Huddlz.Accounts.User.Errors.ResendLimited do
  @moduledoc """
  The account asked for its confirmation email again too soon: once a
  minute and five an hour is the ceiling. Carries which window refused and
  how long until it opens again, so the answer can say when to try.
  """
  use Splode.Error, fields: [:window, :limit, :retry_after_ms], class: :forbidden

  def message(%{window: :minute}), do: "you requested confirmation less than a minute ago"
  def message(%{window: :hour}), do: "you requested confirmation five times in the past hour"

  defimpl Plug.Exception do
    def actions(_), do: []
    def status(_), do: 429
  end

  defimpl AshGraphql.Error do
    def to_error(error) do
      seconds = max(1, div(error.retry_after_ms + 999, 1000))
      message = "#{Exception.message(error)}. Try again in #{seconds} seconds."

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
