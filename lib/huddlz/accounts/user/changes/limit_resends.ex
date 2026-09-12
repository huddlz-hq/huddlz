defmodule Huddlz.Accounts.User.Changes.LimitResends do
  @moduledoc """
  One confirmation email a minute and five an hour per account, counted
  before the transaction so two requests arriving together are counted
  together. Uses the shared `Huddlz.RateLimit` store directly rather than
  the `rate_limit` DSL because the answer needs the wait the store reports,
  not only the window.
  """
  use Ash.Resource.Change

  alias Huddlz.Accounts.User.Errors.ResendLimited
  alias Huddlz.RateLimit

  @windows [{:minute, 1, :timer.minutes(1)}, {:hour, 5, :timer.hours(1)}]

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_transaction(changeset, fn changeset ->
      Enum.reduce_while(@windows, changeset, &check_window/2)
    end)
  end

  defp check_window({window, limit, per}, changeset) do
    case RateLimit.hit(key(changeset.data.id, window), per, limit) do
      {:allow, _count} ->
        {:cont, changeset}

      {:deny, retry_after_ms} ->
        error =
          ResendLimited.exception(window: window, limit: limit, retry_after_ms: retry_after_ms)

        {:halt, Ash.Changeset.add_error(changeset, error)}
    end
  end

  @doc "The store key for one account's window; the per-window limit and length are `window/1`."
  def key(user_id, window), do: "auth:resend_confirmation:#{window}:#{user_id}"

  @doc "The `{limit, per_ms}` of a window."
  def window(name),
    do: @windows |> List.keyfind(name, 0) |> then(fn {_, limit, per} -> {limit, per} end)
end
